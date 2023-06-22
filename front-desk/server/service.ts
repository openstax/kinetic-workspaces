import { randomUUID } from 'crypto'
import { getAnalysis, notifyStartEnclaveRun } from './analysis.js'
import { Worker } from './data.js'
import { editorCookie } from './authentication.js'
import { Analysis, DocumentStatus, MAX_INACTIVY_TIME, POLLING_RATE } from '../definitions.js'
import type { ConfigModel, WorkerModel } from './data.js'
import { startEc2Instance, getEc2Instance, assignHostDNS, startWorkspaceArchive } from './aws.js'
import { reapWorker } from './cleanup.js'
import { validateUserProfile } from './provision.js'

type EditorServiceArgs = {
    analysisId: number
    documentStatus: DocumentStatus
    config: ConfigModel
    getCookie(name: string): string
    setCookie(name: string, value: string): void
}

type WorkerState = {
    isActive: boolean
    hostName?: string
}
export class EditorService {
    args: EditorServiceArgs
    _analysis?: Analysis
    _worker?: WorkerModel

    constructor(args: EditorServiceArgs) {
        this.args = args
    }

    async analysis() {
        if (this._analysis) return this._analysis
        return this._analysis = await getAnalysis(this.args.analysisId, this.args.getCookie(this.args.config.ssoCookieName))
    }

    async startEc2Instance() {
        try {
            await Worker.upsert({ id: this.id, status: 'pending', instanceId: '', lastActivity: new Date() })
            const host = await startEc2Instance(this.args.analysisId)
            console.log("STARTED", host)
            const worker = await Worker.upsert({ id: this.args.analysisId, instanceId: host.InstanceId })
            if (!worker) throw new Error(`failed to upsert worker ${this.args.analysisId}`)
            return { worker, host }
        } catch (e) {
            await Worker.remove({ id: this.id })
            throw e
        }
    }

    get id() {
        return this.args.analysisId
    }

    get isClosed() {
        return this.args.documentStatus == 'closed'
    }

    async worker() {
        if (this._worker) return this._worker
        const { id } = this
        let worker = await Worker.get({ id })
        if (!worker) {
            worker = (await this.startEc2Instance()).worker
        }
        return this._worker = worker
    }

    get lastActivity() {
        return this._worker ? new Date().getTime() - this._worker.lastActivity.getTime() : 0
    }

    async terminateInstance(worker: WorkerModel) {
        await reapWorker(worker)
        return { isActive: false, hostName: '' }
    }

    async updateRunningWorker(worker: WorkerModel): Promise<WorkerState> {
        if (this.args.documentStatus == 'visible') {
            Worker.update({ id: worker.id, lastActivity: new Date() })
        } else if (this.lastActivity > MAX_INACTIVY_TIME) {
            return await this.terminateInstance(worker)
        }

        this.args.setCookie('rs-csrf-token', this.args.getCookie('rs-csrf-token') || randomUUID())
        this.args.setCookie('user-id', await editorCookie(worker, this.args.config, this.args.getCookie('user-id')))
        return { isActive: true, hostName: worker.hostName }
    }

    async archive(message: string): Promise<void> {
//        const analysis = await this.analysis()
        console.log("ARCRUN", { message })
        const run = await notifyStartEnclaveRun(this.args.analysisId, message)

        startWorkspaceArchive({
            key: run.api_key,
            analysis_id: this.args.analysisId,
            analysis_api_key: run.analysis_api_key,
        })
    }

    async update(): Promise<WorkerState> {
        const analysis = await this.analysis()

        const worker = await this.worker()

        if (this.isClosed) {
            await reapWorker(worker)
            return { isActive: false }
        }
        //
        if (worker.status == 'assigned') {
            return await this.updateRunningWorker(worker)
        }

        // enforce polling speed
        if (this.lastActivity < POLLING_RATE) {
            return { isActive: false, hostName: worker.hostName }
        }

        console.log(worker)

        const host = await getEc2Instance(worker.instanceId)
        const hostState = host?.State?.Name || 'unknown'

        if (hostState == 'terminated') {
            await this.startEc2Instance()
            return { isActive: false, hostName: '' }
        }

        // host has finished booting
        if (hostState == 'running') {
            if (!worker.hostName && host.PublicIpAddress) {
                worker.hostName = await assignHostDNS(host)
                await Worker.update({ id: this.id, hostName: worker.hostName })
                await this.updateRunningWorker(worker)
                // return immediatly so that DNS propogates by next tick
                return { isActive: false, hostName: worker.hostName }
            }
            await validateUserProfile(worker, analysis)
            await Worker.update({ id: this.id, status: 'assigned' })
            return { isActive: true, hostName: worker.hostName }
        }


        // unknown state, restart everything
        // await this.terminateInstance(worker)
        // await this.startEc2Instance()

        return { isActive: false, hostName: '' }


    }

}

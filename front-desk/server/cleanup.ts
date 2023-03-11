import { Worker, WorkerModel } from './data.js'
import { MAX_INACTIVY_TIME } from '../definitions.js'
import {
    getEc2Instance, clearHostDNS, terminateEc2Instance, removeEFSAccessPoint,
} from './aws.js'

export async function reapWorker(worker: WorkerModel) {
    console.warn(`terminate ${worker.instanceId} ${worker.hostName}`)
    await Worker.update({ id: worker.id, status: 'terminated' })
    const host = await getEc2Instance(worker.instanceId)
    if (host && host.State?.Name != 'terminated') {
        await terminateEc2Instance(worker.instanceId)
        await clearHostDNS(worker, host)
    }
    await removeEFSAccessPoint(worker)
    await Worker.remove({ id: worker.id }) //, instanceId: undefined, status: 'terminated' })
}

export async function cleanupAbandonedEditors() {
    const assigned = await Worker.scan({ status: 'assigned' })
    const now = new Date().getTime()
    for (const worker of assigned) {
        if (now - worker.lastActivity.getTime() > MAX_INACTIVY_TIME) {
            await reapWorker(worker)
        }
    }
}

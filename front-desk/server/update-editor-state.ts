import { Worker } from './data.js'
import { assignHostDNS, getEc2Instance, terminateEc2Instance, startEc2Instance } from './aws.js'
import { validateUserProfile } from './provision.js'
import type { Analysis } from '../definitions.js'

export type EditorState = {
    isActive: boolean
    hostName? : string
}

const startInstance = async (id: number): Promise<EditorState> => {
    const host = await startEc2Instance(id)

    if (!host?.InstanceId) {
        throw new Error('failed to boot')
    }
    console.log(host)
    Worker.update({ id, status: 'pending', instanceId: host.InstanceId, hostName: '' })
    return { isActive: false }
}

const INACTIVY_TIME = 1000 * 60 * 30 // minutes
const POLLING_RATE = 1000 * 5 //  seconds

export async function updateEditorState(analysis: Analysis, isActive: boolean): Promise<EditorState> {
    const { id } = analysis

    const worker = await Worker.get({ id })
    console.log({ worker })

    if (!worker) {
        Worker.create({ id, status: 'pending', instanceId: '', lastActivity: new Date() })
        try {
            return startInstance(id)
        } catch (err) {
            Worker.remove({ id })  // we do not want entries in db without an ec2 instanceId
            throw err
        }
    }

    if (!worker.instanceId) { Worker.remove({ id }) }

    //Worker.update({ id, accessPointId: null, status: 'assigned' })

    await validateUserProfile(worker, analysis)


    const lastActivity = new Date().getTime() - worker.lastActivity.getTime()

    // happy path, everything is running
    if (worker.status == 'assigned') {
        if (isActive) {
            Worker.update({ id, lastActivity: new Date() })
        } else if (lastActivity > INACTIVY_TIME) {
            //   await backupProfile(worker)
            await terminateEc2Instance(worker.instanceId)
        }
        return { isActive: true, hostName: worker.hostName }
    }

    // enforce polling speed
    if (lastActivity < POLLING_RATE) {
        return { isActive: false, hostName: worker.hostName }
    }

    const host = await getEc2Instance(worker.instanceId)

    if (!host || host.State?.Name == 'terminated') {
        Worker.update({ id, status: 'pending', lastActivity: new Date() })
        return startInstance(id)
    }

    if (host.State?.Name == 'running') {

        if (!worker.hostName && host.PublicIpAddress) {

            const hostName = await assignHostDNS(host)

            const update = await Worker.update({ id, status: 'assigned', hostName })

            Object.assign(worker, update)
            return { isActive: true, hostName: worker.hostName }
        }
        if (!worker.hostName) {
            throw new Error('Failed to record host DNS Name')
        }
    }

    throw new Error(`ec2 host ${worker.instanceId} has unknown state ${worker.status} ${host.State?.Name}`)

}

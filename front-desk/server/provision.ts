import { NodeSSH } from 'node-ssh'
import type { WorkerModel } from './data.js'
import { Worker, getConfig } from './data.js'
import { decodeVar } from './string.js'
import { newRpcError } from './rpc.js'
import { findOrCreateEFSAccessPoint, getProfileUrl } from './aws.js'
import { Analysis, PosixUserId } from '../definitions.js'


const MOUNT = 'sudo mount -t efs -o tls,accesspoint='
// sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport'

async function provisionProfile(worker: WorkerModel, analysis: Analysis) {
    const config = await getConfig()
    console.log("PROVISINING", worker.instanceId, worker.userName)

    if (!worker.accessPointId) {
        worker.accessPointId = await findOrCreateEFSAccessPoint(worker)
        // console.log({ accessPointId })
        if (!worker.accessPointId) throw newRpcError(`accessPoint creation failed`)
        Worker.update({ id: worker.id, accessPointId: worker.accessPointId })
    }

    const ssh = new NodeSSH()
    await ssh.connect({
        host: worker.hostName,
        username: 'ubuntu',
        privateKey: decodeVar(config.editorImageSSHKey),
    })
    const userName = worker.userName

    const hostName = worker.hostName.split('.')[0]

    const cmd = `
        echo 127.0.7.1 ${hostName} ${worker.hostName} | sudo tee -a /etc/hosts && \\
        echo ${hostName} | sudo tee -a /etc/hostname && sudo hostname ${hostName} && \\
        sudo addgroup --gid ${PosixUserId} ${userName} && \\
        sudo adduser --disabled-password --home /home/editor --uid ${PosixUserId} --gid ${PosixUserId} --shell /bin/false --gecos 'Kinetic Workspace User' ${userName} && \\
        sudo ${MOUNT}${worker.accessPointId} ${config.efsAddress}:/ /home/editor
    `
    const resp = await ssh.execCommand(cmd)
    if (resp.code != 0) {
        console.warn(`exit status: ${resp.code}`, cmd, resp.stdout, resp.stderr)
        throw new Error(resp.stderr)
    }
    const fresh = await ssh.execCommand('[ ! -d /home/editor/kinetic ]')
    if (fresh.code == 0) {
        const profileUrl = await getProfileUrl()
        console.log({ profileUrl })
        const resp = await ssh.execCommand(`
            wget -qO- "${profileUrl}" | sudo -u ${userName} tar xz -C /home/editor && \\
            echo "ANALYSIS_API_KEY=${analysis.api_key}" >> /home/editor/.Renviron
        `)
        if (resp.code != 0) {
            throw new Error(resp.stderr)
        }
    }

    return userName
}

export async function validateUserProfile(worker: WorkerModel, analysis: Analysis) {
    // const config = await getConfig()
    console.log('profile', worker)

    if (!worker.hostName) return

    try {
        const userName = await provisionProfile(worker, analysis)
        Worker.update({ id: worker.id, userName })
    } catch (e) {
        console.warn(e)
        Worker.update({ id: worker.id, userName: undefined })
        throw (e)
    }
}

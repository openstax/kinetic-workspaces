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
    const keyLine=`ANALYSIS_API_KEY=${analysis.api_key}`
    const environFile = '/home/editor/.Renviron'

    let cmd = `
        echo 127.0.7.1 ${hostName} ${worker.hostName} | sudo tee -a /etc/hosts && \\
        echo ${hostName} | sudo tee -a /etc/hostname && sudo hostname ${hostName} && \\
        sudo addgroup --gid ${PosixUserId} ${userName} && \\
        sudo adduser --disabled-password --home /home/editor --uid ${PosixUserId} --gid ${PosixUserId} --shell /bin/false --gecos 'Kinetic Workspace User' ${userName} && \\
        sudo ${MOUNT}${worker.accessPointId} ${config.efsAddress}:/ /home/editor && \\
        sudo chown ${userName}.${userName} -R /home/editor && \\
        sudo -u ${userName} bash -c 'grep -q "^ANALYSIS_API_KEY" ${environFile} && sed -i "/^ANALYSIS_API_KEY/c\\${keyLine}" ${environFile} || echo "${keyLine}" >> ${environFile}'
    `

    let resp = await ssh.execCommand(cmd)
    if (resp.code != 0) {
        console.warn(`exit status: ${resp.code}`, cmd, resp.stdout, resp.stderr)
        throw new Error(resp.stderr)
    }

    resp = await ssh.execCommand('[ ! -e /home/editor/kinetic/main.r ]')
    if (resp.code == 0) {
        const profileUrl = await getProfileUrl()
        console.log({ profileUrl })
        cmd = `
            wget -qO- "${profileUrl}" | sudo -u ${userName} tar xz --skip-old-files --directory /home/editor && \\
            sudo -u ${userName} perl -MTime::Piece -pi -e 's/(cutoff_date\\s*=\\s*")\\d{4}-\\d{2}-\\d{2}(")/$1 . Time::Piece->new->ymd . $2/ge' /home/editor/kinetic/main.r && \\
            rm -fr /home/editor/kinetic/data/* && \\
            sudo -u ${userName} bash -c "cd /home/editor/kinetic && R -f /home/editor/kinetic/main.r"
        `
        console.log("PROVISION", cmd)
        resp = await ssh.execCommand(cmd)
        if (resp.code != 0) {
            console.warn(cmd, resp.stderr)
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

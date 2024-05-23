import Stream from 'stream'
import type { RunPayload } from './types'
import { createHash } from 'node:crypto'
import {
    getProcessPayload, setWorkingDirectory, signalSuccess, signalFailure, shutdownHost,
    followAndLogProgress, ecrAuthorization, docker, log, postToKinetic, IMAGE_REPO, Timer,
} from './shared'
import { execSync } from 'child_process'
import fs from 'fs'
import fetch from 'node-fetch'

const args = getProcessPayload<RunPayload>()

const dockerImage = IMAGE_REPO + ':' + args.key

setWorkingDirectory()
    .then(pullDockerImage)
    .then(runDockerImage)
    .then(uploadResults)
    .then((output) => signalSuccess({ ...args, ...output, success: true }))
    .then(shutdownHost)
    .catch(signalFailure)


type UploadResult = {
    signed_id: string
    direct_upload: {
        url: string,
        headers: Record<string, string>
    }
}

async function uploadResults() {
    const timer = Timer.start()
    execSync(`zip -r output.zip output`)
    const fileBuff = fs.readFileSync("output.zip")
    const checksum = createHash('md5').update(fileBuff).digest("base64")
    console.log({ checksum })
    const result = await postToKinetic<UploadResult>('upload_results', {
        blob: {
            filename: 'output.zip', byte_size: fileBuff.byteLength,
            content_type: 'application/zip', checksum,
        }
    })

    const readStream = fs.createReadStream('output.zip')

    const upload = await fetch(result.direct_upload.url, {
        method: 'PUT',
        headers: {
            'content-type': 'application/zip',
            'content-length': fileBuff.byteLength.toString(),
            'content-md5': checksum,
        },
        body: readStream,
    })

    if (!upload.ok) {
        const body = await upload.text()
        throw new Error(`failed to upload results: ${upload.status} ${upload.statusText} ${body}`)
    }

    log('run', 'debug', `uploaded results ${timer.elapsed()}`)

    return {
        output_signed_id: result.signed_id,
    }
}

async function pullDockerImage() {
    const authconfig = await ecrAuthorization()
    await followAndLogProgress('run', `pull ${dockerImage}`, (logger) => {
        docker.pull(dockerImage, { authconfig }, logger)
    })
}

async function runDockerImage() {
    const ws = new Stream.Writable({
        write(chunk, _, next) {
            log('run', 'info', chunk.toString())
            next()
        }
    })
    const outputDir = process.cwd() + '/output'
    fs.mkdirSync(outputDir)

    await docker.run(dockerImage, ['R', '-f', 'main.r'], ws, {
        HostConfig: {
            Binds: [
                `${outputDir}:/home/editor/kinetic/output`,
            ]
        }
    })

}

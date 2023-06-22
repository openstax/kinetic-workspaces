import Stream from 'stream'
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import type { RunPayload } from './types'
import {
    getProcessPayload, setWorkingDirectory, signalSuccess, signalFailure, shutdownHost,
    followAndLogProgress, ecrAuthorization, docker, IMAGE_REPO,
} from './shared'
import { execSync } from 'child_process'
import fs from 'fs'

const args = getProcessPayload<RunPayload>()

const dockerImage = IMAGE_REPO + ':' + args.key

setWorkingDirectory()
    .then(pullDockerImage)
    .then(runDockerImage)
    .then(uploadResults)
    .then(({ output_path }) => signalSuccess({ ...args, success: true, output_path }))
    .then(shutdownHost)
    .catch(signalFailure)

async function uploadResults() {
    console.log('uploading results', process.cwd())
    execSync(`cd output; zip -r ../output.zip *`)
    const archive = new URL(args.archive_path)
    const s3 = new S3Client({ region: args.region })
    const path = archive.pathname
        .replace(/^\//, '')
        .replace(/\/[^\/]*$/, '')
    const Bucket = archive.host.split('.')[0]
    const Key = `${path}/output.zip`
    await s3.send(new PutObjectCommand({
        Body: fs.createReadStream('output.zip'),
        Bucket,
        Key,
    }))
    return {
        output_path: `s3://${Bucket}/${Key}`
    }
}

async function pullDockerImage() {
    const authconfig = await ecrAuthorization()
    await followAndLogProgress(`pull ${dockerImage}`, (logger) => {
        docker.pull(dockerImage, { authconfig }, logger)
    })
}

async function runDockerImage() {
    const ws = new Stream.Writable({
        write(chunk, _, next) {
            console.log(chunk.toString())
            next()
        }
    })
    const outputDir = process.cwd() + '/output'
    fs.mkdirSync(outputDir)

    await docker.run(dockerImage, ['R', '-f', 'main.r'], ws, {
        HostConfig: {
            Binds: [
                `${process.cwd()}/output:/home/editor/kinetic/output`,
            ]
        }
    })

}

import { writeFile } from 'fs/promises'
import { createWriteStream } from 'node:fs'
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3"
import Docker, { AuthConfig } from 'dockerode'
import { Readable } from 'stream'
import { URL } from 'node:url'
import {
    BASE_IMAGE_URL,
    getProcessPayload, setWorkingDirectory, followAndLogProgress, signalSuccess, signalFailure, shutdownHost, ecrAuthorization
} from './shared'
import type { AnalyzePayload } from './types'

const args = getProcessPayload<AnalyzePayload>()

console.log(
    JSON.stringify(args, null, 2)
)

//const BASE_IMAGE_URL = new URL(args.base_image.startsWith('http') ? args.base_image : `https://${args.base_image}`)
const REPO = BASE_IMAGE_URL.host + BASE_IMAGE_URL.pathname.split(':')[0]
const DEST_IMAGE_TAG = REPO + ':' + args.key
const ARCHIVE_NAME = 'archive.tar.zst'


const docker = new Docker()

setWorkingDirectory()
    .then(downloadArchive)
    .then(buildDockerImage)
    .then(uploadImage)
    .then(() => signalSuccess(args.task_token, { ...args, image: DEST_IMAGE_TAG, task_token: null }))
    .catch((err) => signalFailure(args.task_token, err))
    .then(shutdownHost)



async function downloadArchive() {
    const path = new URL(args.archive_path)

    const s3 = new S3Client({ region: 'us-east-1' })
    const b = {
        Bucket: path.host.split('.')[0],
        Key: path.pathname.replace(/^\//, ''),
    }
    const { Body: body }  = await s3.send(new GetObjectCommand(b))
    if (body instanceof Readable) {
        body.pipe(createWriteStream(ARCHIVE_NAME));

    } else {
        throw new Error('no body, or not readable')
    }
}


// export async function signalSuccess() {
//     const output:AnalyzeBuildEventOutput = {
//         ...args,
//         image: DEST_IMAGE_TAG,
//     }
//     await SFN.send(new SendTaskSuccessCommand({
//         taskToken: args.task_token,
//         output: JSON.stringify(output),
//     }))

// }

// export async function signalFailure(error: any) {
//     await SFN.send(new SendTaskFailureCommand({
//         taskToken: args.task_token,
//         error: String(error).slice(0, 255),
//         cause: error instanceof Error ? error.stack : '',
//     }))
// }


async function buildDockerImage() {
    // https://github.com/apocas/dockerode/issues/448#issuecomment-384801924

    // const authReply = await ECR.send(new GetAuthorizationTokenCommand({registryIds: [registryId]}))
    // const auth = authReply.authorizationData?.[0] || {}
    // let [username, password] = Buffer.from((auth.authorizationToken || ''), 'base64').toString().split(':');

    // const authconfig: AuthConfig = { username, password, serveraddress: BASE_IMAGE_URL.host }

    const authconfig = await ecrAuthorization()

    await followAndLogProgress(`pull from: ${args.base_image}`, docker.modem, (logger) => {
        docker.pull(args.base_image, { authconfig }, logger)
    })

    await writeFile('Dockerfile', `
        FROM ${args.base_image}
        RUN apt-get install zstd
        WORKDIR /app
        COPY archive.tar.zst .
        RUN tar xf archive.tar.zst
        WORKDIR /app/3/kinetic
        ENV ANALYSIS_API_KEY=${args.analysis_api_key}
        ENV ENCLAVE_API_KEY=${args.enclave_api_key}
        RUN R -e 'renv::restore()'
    `.replace(/\n\s+/g, '\n'));

    const stream = await docker.buildImage({
        context: process.cwd(), src: ['Dockerfile', ARCHIVE_NAME],
    }, { t: DEST_IMAGE_TAG, authconfig })
    if (stream) {
        await new Promise((resolve, reject) => {
            docker.modem.followProgress(stream, (err, res) => {
                console.log(res)
                err ? reject(err) : resolve(res)
            });
        });
    }

}


async function uploadImage() {
    const authconfig = await ecrAuthorization()

    const img = docker.getImage(DEST_IMAGE_TAG)
    await followAndLogProgress(`pushing to tag ${args.key}`, docker.modem, (logger) => {
        img.push({ tag: args.key, authconfig }, logger)
    })
}

import { writeFile, mkdtemp } from 'fs/promises'
import { createWriteStream } from 'node:fs'
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3"
import { SFNClient, SendTaskFailureCommand, SendTaskSuccessCommand } from "@aws-sdk/client-sfn"
import { ECRClient, GetAuthorizationTokenCommand } from "@aws-sdk/client-ecr"
import Docker, { AuthConfig } from 'dockerode'
import { Readable } from 'stream'
import { URL } from 'node:url'

import type { AnalyzeBuildEventOutput, AnalyzePayload } from './types'

const args: AnalyzePayload  = JSON.parse(Buffer.from(process.argv[2], 'base64').toString())

console.log(
    process.argv[2],
    JSON.stringify(args, null, 2)
)


// const ENCLAVE_KEY = process.argv[2]
// const STEP_TOKEN = process.argv[3]

// const API_KEY = process.argv[3]
// const SNAPSHOTARG = process.argv[4]
// const IMGARG = process.argv[5]

const BASE_IMAGE_URL = new URL(args.base_image.startsWith('http') ? args.base_image : `https://${args.base_image}`)
const REPO = BASE_IMAGE_URL.host + BASE_IMAGE_URL.pathname.split(':')[0]
const DEST_IMAGE_TAG = REPO + ':' + args.key
const ARCHIVE_NAME = 'archive.tar.zst'
// const TAG = process.argv[6]
// const DEST_TAG = IMG_URL.host + IMG_URL.pathname.split(':')[0] + ':' + TAG

const registryId = BASE_IMAGE_URL.host.split('.')[0]
const docker = new Docker()
const SFN = new SFNClient({region: args.region })
const ECR = new ECRClient({ region: args.region })

setWorkingDirectory()
    .then(downloadArchive)
    .then(buildDockerImage)
    .then(uploadImage)
    .then(signalSuccess)
    .catch(signalFailure)

async function signalSuccess() {
    const output:AnalyzeBuildEventOutput = {
        ...args,
        image: DEST_IMAGE_TAG,
    }
    await SFN.send(new SendTaskSuccessCommand({
        taskToken: args.task_token,
        output: JSON.stringify(output),
    }))

}

async function signalFailure(error: any) {
    await SFN.send(new SendTaskFailureCommand({
        taskToken: args.task_token,
        error: String(error).slice(0, 255),
        cause: error instanceof Error ? error.stack : '',
    }))

}

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

async function setWorkingDirectory() {
    const dir = await mkdtemp('enclave')
    process.chdir(dir)
    return dir
}

async function buildDockerImage() {
    // https://github.com/apocas/dockerode/issues/448#issuecomment-384801924

    const authReply = await ECR.send(new GetAuthorizationTokenCommand({registryIds: [registryId]}))
    const auth = authReply.authorizationData?.[0] || {}
    let [username, password] = Buffer.from((auth.authorizationToken || ''), 'base64').toString().split(':');

    const authconfig: AuthConfig = { username, password, serveraddress: BASE_IMAGE_URL.host }

    const reply = await docker.pull(args.base_image, { authconfig })
    if (reply.statusCode != 200) throw new Error('failed to pull image')

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
    }, { t: DEST_IMAGE_TAG })
    if (stream) {
        await new Promise((resolve, reject) => {
            docker.modem.followProgress(stream, (err, res) => {
                console.log(res)
                err ? reject(err) : resolve(res)
            });
        });
    }


    return authconfig
}


async function uploadImage(authconfig: AuthConfig) {
//    return
    const img = docker.getImage(DEST_IMAGE_TAG)

    const stream = await img.push({
        tag: args.key,
        authconfig,
    })

    if (stream) {

        await new Promise((resolve, reject) => {
            docker.modem.followProgress(stream, (err, res) => {
                console.log(res)
                err ? reject(err) : resolve(res)
            });
        });
    }

}

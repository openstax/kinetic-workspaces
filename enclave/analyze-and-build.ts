import { writeFile, mkdtemp } from 'fs/promises'
import { createWriteStream } from 'node:fs'
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3"
import { SFNClient, SendTaskFailureCommand, SendTaskSuccessCommand } from "@aws-sdk/client-sfn"
import { ECRClient, GetAuthorizationTokenCommand } from "@aws-sdk/client-ecr"
import Docker, { AuthConfig } from 'dockerode'
import { Readable } from 'stream'
import { URL } from 'node:url'

import type { AnalyzeBuildEventOutput, AnalyzePayload } from './types'
import { exec } from 'node:child_process'

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
    .then(shutdownHost)


async function shutdownHost() {
    exec('sudo shutdown now')
}

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
class Timer {
    startTime: Date
    constructor() {
        this.startTime = new Date();
    }

    static start() {
        return new Timer()
    }

    end() {
        const endTime = new Date();
        const elapsedTime = endTime.getTime() - this.startTime.getTime()
        return elapsedTime / 1000;
    }
}

const followProgressCB = (activity: string, resolve: any, reject: any) => (err: any, stream: any) => {
    const timer = Timer.start()
    console.log(`starting ${activity}`)
    const fail = (err:any) => {
        console.log(`${activity} failed after ${timer.end()} seconds`)
        reject(err)
    }
    if (err) {
        fail(err)
    } else {
        docker.modem.followProgress(stream,
            (err, status) => {  // completion callback
                // console.log({ err, status })
                const errorStatus = status.find(s => s?.error)
                if (errorStatus) {
                    console.log(errorStatus)
                    fail(errorStatus.error)
                } else if (err) {
                    fail(err)
                }
                else {
                    console.log(`finished ${activity} (${timer.end()} seconds)`)
                    resolve(status)
                }
            },
            // (status) => console.log(`progress status: ${status}`) // very verbose
        )
    }
}

async function buildDockerImage() {
    // https://github.com/apocas/dockerode/issues/448#issuecomment-384801924

    const authReply = await ECR.send(new GetAuthorizationTokenCommand({registryIds: [registryId]}))
    const auth = authReply.authorizationData?.[0] || {}
    let [username, password] = Buffer.from((auth.authorizationToken || ''), 'base64').toString().split(':');

    const authconfig: AuthConfig = { username, password, serveraddress: BASE_IMAGE_URL.host }



    await new Promise((resolve, reject) => {
        docker.pull(args.base_image, { authconfig }, followProgressCB(`pull from: ${args.base_image}`, resolve, reject))
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
    return authconfig
}


async function uploadImage(authconfig: AuthConfig) {
//    return
    const img = docker.getImage(DEST_IMAGE_TAG)

    await new Promise((resolve, reject) => {
        img.push({
            tag: args.key,
            authconfig,
        }, followProgressCB(`pushing to tag ${args.key}`, resolve, reject))
    })
    // if (stream) {

    //     await new Promise((resolve, reject) => {
    //         docker.modem.followProgress(stream, (err, res) => {
    //             console.log(res)
    //             err ? reject(err) : resolve(res)
    //         });
    //     });
    // }

}

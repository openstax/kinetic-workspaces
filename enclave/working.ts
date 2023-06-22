import { SFNClient, SendTaskSuccessCommand } from "@aws-sdk/client-sfn"
import { writeFile, mkdtemp } from 'fs/promises'
import { createWriteStream } from 'node:fs'
import { execSync } from 'node:child_process'
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3"
import { ECRClient, GetAuthorizationTokenCommand, PutImageCommand } from "@aws-sdk/client-ecr"
import Docker, { AuthConfig } from 'dockerode'

import { Readable } from 'stream'
import { URL } from 'node:url'

const ENCLAVE_KEY = process.argv[2]
const API_KEY = process.argv[3]
const SNAPSHOTARG = process.argv[4]
const IMGARG = process.argv[5]

const IMG_URL = new URL(IMGARG.startsWith('http') ? IMGARG : `https://${IMGARG}`)
const TAG = process.argv[6]
const DEST_TAG = IMG_URL.host + IMG_URL.pathname.split(':')[0] + ':' + TAG

const IMG = IMG_URL.host + IMG_URL.pathname

const SNAPSHOT = new URL(SNAPSHOTARG)


const ECR = new ECRClient({ region: 'us-east-1' })
const registryId = IMG_URL.host.split('.')[0]
const docker = new Docker()

//console.log(IMG_URL)


//mkdtemp('enclave')
new Promise<string>(r => r('./temp'))
    .then((dir) => {
        process.chdir(dir)
        console.log(`Working in: ${dir}`)
    })
//    .then(download)
    .then(build)
    .then(upload)

async function download() {
    const s3 = new S3Client({ region: 'us-east-1' })
    const b = {
        Bucket: SNAPSHOT.host,
        Key: SNAPSHOT.pathname.replace(/^\//, ''),
    }
    const { Body: body }  = await s3.send(new GetObjectCommand(b))
    if (body instanceof Readable) {
        body.pipe(createWriteStream('archive.zst'));
        execSync("tar xf archive.zst")
    } else {
        throw new Error('no body, or not readable')
    }
}

async function upload(authconfig: Docker.AuthConfig) {
//    return
    const img = docker.getImage(DEST_TAG) // '373045849756.dkr.ecr.us-east-1.amazonaws.com/kinetic_workspaces:test-123') // 4b87bd85e092') //enclave-build')
    //const s = await img.tag({ repo: '373045849756.dkr.ecr.us-east-1.amazonaws.com/kinetic_workspaces', tag: 'test-123' })

    // console.log( img, s.toString())
//return

    const stream = await img.push({
        tag: TAG,
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

//    console.log(resp)
//     const manifest = await img.inspect()
// console.log(manifest)
//     const response = await ECR.send(new PutImageCommand({ // PutImageRequest
//         registryId,
//         repositoryName: 'kinetic_workspaces',
//         imageManifest: JSON.stringify(manifest),
//         imageTag: 'test'
//     }));

    //     console.log(response)
}

async function build() {
    // https://github.com/apocas/dockerode/issues/448#issuecomment-384801924

    const authReply = await ECR.send(new GetAuthorizationTokenCommand({registryIds: [registryId]}))
    const auth = authReply.authorizationData?.[0] || {}
    let [username, password] = Buffer.from((auth.authorizationToken || ''), 'base64').toString().split(':');
console.log({ registryId, sa: IMG_URL.host, img: IMG })
    const authconfig: Docker.AuthConfig = { username, password, serveraddress: IMG_URL.host }

    const reply = await docker.pull(IMG, { authconfig })

    console.log(reply.statusCode)

process.exit(0)

    // await docker.buildImage({

    // })



    await writeFile('Dockerfile', `
        FROM ${IMG}
        RUN apt-get install zstd
        WORKDIR /app
        COPY archive.tar.zst .
        RUN tar xf archive.tar.zst
        WORKDIR /app/3/kinetic
        ENV ANALYSIS_API_KEY=${API_KEY}
        ENV ENCLAVE_API_KEY=${ENCLAVE_KEY}
        RUN R -e 'renv::restore()'
    `.replace(/\n\s+/g, '\n'));

    const stream = await docker.buildImage({
        context: process.cwd(), src: ['Dockerfile', 'archive.tar.zst'],
    }, { t: DEST_TAG })
    if (stream) {
        await new Promise((resolve, reject) => {
            docker.modem.followProgress(stream, (err, res) => {
                console.log(res)
                err ? reject(err) : resolve(res)
            });
        });
    }



    // const build = await docker.image.build(dockerFile as any, { t: 'enclave-test' })

    return authconfig
}


// async function sendSuccess() {
//     const client = new SFNClient({
//         region: 'us-east-1',
//     })
//     await client.send(new SendTaskSuccessCommand({
//         taskToken: TOKEN,
//         output: JSON.stringify({ foo: 'bar' }),
//     }))
// }


// sendSuccess()

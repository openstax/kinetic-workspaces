import { writeFile } from 'fs/promises'
import { createWriteStream } from 'node:fs'
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3"
import { execSync } from 'child_process'
import { Readable } from 'stream'
import { URL } from 'node:url'
import {
    IMAGE_REPO, docker,
    getProcessPayload, setWorkingDirectory, followAndLogProgress, signalSuccess, signalFailure, shutdownHost, ecrAuthorization
} from './shared'
import type { AnalyzePayload } from './types'

const args = getProcessPayload<AnalyzePayload>()

const DEST_IMAGE_TAG = IMAGE_REPO + ':' + args.key
const ARCHIVE_NAME = 'archive.tar.zst'

setWorkingDirectory()
    .then(downloadArchive)
    .then(buildDockerImage)
    .then(uploadImage)
    .then(() => signalSuccess({ ...args, image: DEST_IMAGE_TAG }))
    .catch(signalFailure)
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
        const stream = createWriteStream(ARCHIVE_NAME)
        body.pipe(stream);
        await new Promise((resolve) => stream.on("finish", resolve))
    } else {
        throw new Error('no body, or not readable')
    }
    execSync(`tar xf ${ARCHIVE_NAME}`)
}


async function buildDockerImage() {

    const authconfig = await ecrAuthorization()

    await followAndLogProgress(`pull from: ${args.base_image}`, (logger) => {
        docker.pull(args.base_image, { authconfig }, logger)
    })

    await writeFile('Dockerfile', `
        FROM ${args.base_image}
        RUN apt-get install zstd
        WORKDIR /home
        COPY archive editor
        WORKDIR /home/editor/kinetic
        ENV ANALYSIS_API_KEY=${args.analysis_api_key}
        ENV ENCLAVE_API_KEY=${args.enclave_api_key}
        RUN R -e 'renv::restore()'
    `.replace(/\n\s+/g, '\n'));

    await followAndLogProgress(`building image`, (logger) => {
        docker.buildImage({
            context: process.cwd(), src: ['Dockerfile', 'archive'],
        }, { t: DEST_IMAGE_TAG, authconfig }, logger)
    })

    // const stream = await docker.buildImage({
    //     context: process.cwd(), src: ['Dockerfile', ARCHIVE_NAME],
    // }, { t: DEST_IMAGE_TAG, authconfig })
    // if (stream) {
    //     await new Promise((resolve, reject) => {
    //         docker.modem.followProgress(stream, (err, res) => {
    //             console.log(res)
    //             err ? reject(err) : resolve(res)
    //         });
    //     });
    // }

}


async function uploadImage() {
    const authconfig = await ecrAuthorization()

    const img = docker.getImage(DEST_IMAGE_TAG)
    await followAndLogProgress(`pushing to tag ${args.key}`, (logger) => {
        img.push({ tag: args.key, authconfig }, logger)
    })
}

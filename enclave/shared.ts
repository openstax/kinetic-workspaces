import { exec } from 'node:child_process'
import { mkdtemp } from 'fs/promises'

import { SFNClient, SendTaskFailureCommand, SendTaskSuccessCommand } from "@aws-sdk/client-sfn"
import { ECRClient, GetAuthorizationTokenCommand } from "@aws-sdk/client-ecr"
import type { AuthConfig } from 'dockerode'
import Docker from 'dockerode'

export const args  = JSON.parse(Buffer.from(process.argv[2], 'base64').toString())

console.log(
    JSON.stringify(args, null, 2)
)

export const BASE_IMAGE_URL = new URL(args.base_image.startsWith('http') ? args.base_image : `https://${args.base_image}`)
export const IMAGE_REPO = BASE_IMAGE_URL.host + BASE_IMAGE_URL.pathname.split(':')[0]
export const SFN = new SFNClient({region: args.region })
export const ECR = new ECRClient({ region: args.region })

export function getProcessPayload<T>(){ return args as T }

export const docker = new Docker()

const registryId = BASE_IMAGE_URL.host.split('.')[0]
let _ecrAuthorization: AuthConfig | null = null

export async function ecrAuthorization() {
    if (_ecrAuthorization) return _ecrAuthorization
    // https://github.com/apocas/dockerode/issues/448#issuecomment-384801924
    const authReply = await ECR.send(new GetAuthorizationTokenCommand({registryIds: [registryId]}))
    const auth = authReply.authorizationData?.[0] || {}
    let [username, password] = Buffer.from((auth.authorizationToken || ''), 'base64').toString().split(':');

    return _ecrAuthorization = { username, password, serveraddress: BASE_IMAGE_URL.host } as AuthConfig
}

export class Timer {
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

type CB = (logger: (err: any, stream: any) => void) => void

export const followAndLogProgress = (activity: string, cb: CB, verbose = false) => {

    return new Promise((resolve, reject) => {
        cb((err: any, stream: any) => {

            const timer = Timer.start()
            console.log(`starting ${activity}`)
            const fail = (err: any) => {
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
                        } else {
                            console.log(`finished ${activity} (${timer.end()} seconds)`)
                            resolve(status)
                        }
                    },
                    (status) => { if (verbose) { console.log(`status: ${status}`) } }
                )
            }

        })
    })
}

export async function setWorkingDirectory() {
    const dir = await mkdtemp('enclave')
    process.chdir(dir)
    console.log(`working directory: ${process.cwd()}`)
    return dir
}


export async function signalSuccess(output: any) {
    await SFN.send(new SendTaskSuccessCommand({
        taskToken: args.task_token,
        output: JSON.stringify(output),
    }))
}

export async function signalFailure(error: any) {
    console.warn(`task failed: ${error}`)
    await SFN.send(new SendTaskFailureCommand({
        taskToken: args.task_token,
        error: String(error).slice(0, 255),
        cause: error instanceof Error ? error.stack : '',
    }))
}


export async function shutdownHost() {
    exec('sudo shutdown now')
}



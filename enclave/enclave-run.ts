import type { RunPayload } from './types'
import {
    getProcessPayload, setWorkingDirectory, signalSuccess, signalFailure, shutdownHost,
} from './shared'


const args = getProcessPayload<RunPayload>()

console.log( args )

setWorkingDirectory()
    .then(() => signalSuccess(args.task_token, { ...args, hello: 'world' }))
    .catch((err) => signalFailure(args.task_token, err))
    .then(shutdownHost)

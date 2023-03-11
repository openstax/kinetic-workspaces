import * as crypto from 'crypto'
import { compactDecrypt, compactVerify, importSPKI } from 'jose'
import dayjs from 'dayjs'
import type { User } from '../definitions.js'
import { ConfigModel, WorkerModel, Worker, getConfig } from './data.js'
import { decodeVar, randomString } from './string.js'


export async function getUserFromCookieValue(value: string) {
    const config = await getConfig()
    const { plaintext } = await compactDecrypt(value,
        Buffer.from(decodeVar(config.ssoCookiePrivateKey)),
        { contentEncryptionAlgorithms: ['A256GCM'], keyManagementAlgorithms: ['dir'] },
    )
    const { payload } = await compactVerify(
        plaintext,
        await importSPKI(decodeVar(config.ssoCookiePublicKey), 'RS256'),
        { algorithms: ['RS256'] },
    )
    return JSON.parse(payload.toString()) as User
}


export async function newEditorCookie(worker: WorkerModel, config: ConfigModel) {
    if (!worker.userName) {
        worker.userName = randomString()
        await Worker.update({ id: worker.id, userName: worker.userName })
        console.log("SET USERNAME: ", worker.userName)
    }
    const expires = dayjs().add(3, 'month').format('ddd, DD MMM YYYY H:MM:ss') + ' GMT' // rstudio format in core/http/Util.cpp
    const hmac = crypto
        .createHmac('sha256', config.rstudioCookieSecret + String.fromCharCode(0x0A))
        .update(worker.userName + expires).digest('base64')
    const kDelim = '|'
    return encodeURIComponent(worker.userName) + kDelim + encodeURIComponent(expires) + kDelim + encodeURIComponent(hmac)
}

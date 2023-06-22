import * as crypto from 'crypto'
import { compactDecrypt, compactVerify, importSPKI } from 'jose'
import dayjs from 'dayjs'
import customParseFormat from 'dayjs/plugin/customParseFormat'
dayjs.extend(customParseFormat)
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

const COOKIE_DATE_FORMAT = 'ddd, DD MMM YYYY HH:MM:ss'

export async function editorCookie(worker: WorkerModel, config: ConfigModel, existingCookie: string) {
    if (existingCookie) {
        const date = dayjs(existingCookie, COOKIE_DATE_FORMAT, true)
        if (date.isAfter(dayjs().add(1, 'week'))) {
            return encodeURIComponent(existingCookie)
        }
    }
    if (!worker.userName) {
        worker.userName = randomString()
        await Worker.update({ id: worker.id, userName: worker.userName })
        console.log("SET USERNAME: ", worker.userName)
    }
    // rstudio format in core/http/Util.cpp
    const expires = dayjs().add(3, 'month').format(COOKIE_DATE_FORMAT) + ' GMT'

    const hmac = crypto
        .createHmac('sha256', config.rstudioCookieSecret + String.fromCharCode(0x0A))
        .update(worker.userName + expires).digest('base64')
    const kDelim = '|'
    return encodeURIComponent(worker.userName) + kDelim + encodeURIComponent(expires) + kDelim + encodeURIComponent(hmac)
}

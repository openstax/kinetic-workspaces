import { APIGatewayProxyHandler, ScheduledEvent, ScheduledHandler } from 'aws-lambda'
import * as cookie from 'cookie'
import { getConfig } from './data.js'
import type { StatusParams } from '../definitions.js'
import { newRpcError, newRpcSuccess } from './rpc.js'
import { EditorService } from './service.js'
import { cleanupAbandonedEditors } from './cleanup.js'
import './polyfill.js'


function isScheduledEvent(event: any): event is ScheduledEvent {
    return event['detail-type'] == 'Scheduled Event'
}


export const handler = async (event: any, context: any, cb: any) => {
    // console.log(JSON.stringify(event, null, 4)) // eslint-disable-line no-console
    if (isScheduledEvent(event)) {
        return scheduledHandler(event, context, cb)
    }
    return apiHandler(event, context, cb)
}

const scheduledHandler: ScheduledHandler = async () => {
    await cleanupAbandonedEditors()
}

const apiHandler: APIGatewayProxyHandler = async (event: any) => {
    const config = await getConfig()

    const cookies = cookie.parse(event.headers.cookie || '')

    const params = JSON.parse(event.body || '{}') as StatusParams
    const newCookies: string[] = []
    const service = new EditorService({
        config,
        analysisId: params.analysisId,
        documentStatus: params.documentStatus,
        getCookie(name: string) {
            return cookies[name]
        },
        setCookie(name: string, value: string) {
            newCookies.push(
                cookie.serialize(name, value, {
                    httpOnly: true, secure: true, encode: String, domain: config.dnsZoneName,
                })
            )
        },
    })

    try {
        if (params.archiveMessage) {
            await service.archive(params.archiveMessage)
        }
        const status = await service.update()
        return {
            statusCode: 201,
            cookies: newCookies,
            body: JSON.stringify(newRpcSuccess(status)),
        };
    } catch (err: any) {
        console.warn(err)
        return { statusCode: 500, body: JSON.stringify(newRpcError(err)) }
    }
}

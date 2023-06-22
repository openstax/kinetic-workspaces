import { Handler } from 'aws-lambda'
import fetch from 'node-fetch'
import type { EventInput } from './types'

type NotifyInput = EventInput & {
    error?: any
}

type Event = {
    input: NotifyInput
    script: string
    token: string
}

export const handler: Handler<Event> = async ({ input }) => {

    fetch(process.env.KINETIC_URL + '/api/v1/enclave/runs/notify', {
        method: 'PUT',
        body: JSON.stringify({
            ...input,
            status: input.error ? 'failure' : 'success',
        })
    })
}

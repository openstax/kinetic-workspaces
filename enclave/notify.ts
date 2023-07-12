import { Handler } from 'aws-lambda'
import fetch from 'node-fetch'
import type { EventInput } from './types'


type NotifyInput = EventInput & {
    output_path: string
    error?: any
    output_signed_id: string
}

export const handler: Handler<NotifyInput> = async (input) => {
    const url = `${input.kinetic_url}api/v1/enclave/runs/completion`
    console.log("running notify handler", url, input)
    const status = input.error ? 'failure' : 'success'
    const results = await fetch(url, {
        method: 'PUT',
        headers: { Authorization: `Bearer ${input.enclave_api_key}`, "Content-Type": "application/json" },
        body: JSON.stringify({
            status,
            api_key: input.key,
            output_path: input.output_path,
            archive_path: input.archive_path,
            output_signed_id: input.output_signed_id,
        })
    })

    if (!results.ok) {
        throw new Error(`failed to notify results: ${results.status} ${results.statusText}`)
    }

    return { success: true }
}

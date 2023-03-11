import type { ErrorTypes } from '@nathanstitt/sundry'

import type { RPCSuccess, RPCError, StatusParams, EditorState } from './definitions.js'

export function isRPCError(err: any): err is RPCError {
    return typeof err === 'object' && err.error === true
}

export function isRPCSuccess(err: any): err is RPCSuccess {
    return typeof err === 'object' && err.error === false
}

export function newRpcError(err: ErrorTypes, code?: string): RPCError {
    return {
        code,
        error: true,
        message: typeof err === 'object' && err.message ? err.message : String(err),
    }
}

export function newRpcSuccess<D extends Record<string, any>>(
    data: D = {} as any
): RPCSuccess<D> {
    return {
        error: false,
        data,
    }
}


type ReturnTypes = RPCError | RPCSuccess<EditorState>

export async function updateWorkspaceStatus(params: StatusParams): Promise<ReturnTypes> {
    const resp = await fetch(`/status`, {
        method: 'PUT',
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(params),
    })
    if (!resp.ok) {
        return newRpcError(resp.statusText)
    }
    return await resp.json() as ReturnTypes
}

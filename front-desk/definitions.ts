export type DocumentStatus = 'visible' | 'hidden' | 'closed'

export type StatusParams = {
    analysisId: number
    documentStatus: DocumentStatus
    archiveMessage?: string
}

export type EditorState = {
    isActive: boolean
    hostName? : string
}

export interface RPCSuccess<D extends Record<string, any> = object> {
    error: false
    data: D
}

export interface RPCError {
    code?: string
    message: string
    error: true
}

export type RPCResponse<D extends Record<string, any> = object> = RPCSuccess<D> | RPCError

export interface User {
    id: number;
    name: string;
    first_name: string;
    last_name: string;
    full_name: string;
    uuid: string;
    faculty_status: string;
    is_administrator: boolean;
    is_not_gdpr_location: boolean;
    contact_infos: Array<{
        type: string;
        value: string;
        is_verified: boolean;
        is_guessed_preferred: boolean;
    }>;
}

export type Analysis = {
    id: number;
    name: string;
    description: string;
    repository_url: string;
    api_key: string;
}

export type AnalysisRunResponse = {
    api_key: string
    started_at: string
    analysis_api_key: string
    is_completed: boolean
}

export const PosixUserId = 1010

export const MAX_INACTIVY_TIME = 1000 * 60 * 30 // minutes
export const POLLING_RATE = 1000 * 5 //  seconds

export type StartArchiveArgs = {
    key: string
    analysis_id: number
    kinetic_url: string
    analysis_api_key: string
}

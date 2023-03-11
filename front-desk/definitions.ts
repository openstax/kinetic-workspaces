export type DocumentStatus = 'visible' | 'hidden' | 'closed'

export type StatusParams = {
    analysisId: number
    documentStatus: DocumentStatus
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

export interface Analysis {
    id: number;
    name: string;
    description: string;
    repository_url: string;
    api_key: string;
}

export const PosixUserId = 1010

export const MAX_INACTIVY_TIME = 1000 * 60 * 30 // minutes
export const POLLING_RATE = 1000 * 5 //  seconds

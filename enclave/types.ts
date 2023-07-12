export type EventInput = {
    key: string
    archive_path: string
    kinetic_url: string
    analysis_id: number
    analysis_api_key: string
    enclave_api_key: string
    region: string
    base_image: string
    task_token: string
}


export type AnalyzeBuildEventOutput = {
    key: string
    archive_path: string
    analysis_id: number
    analysis_api_key: string
    enclave_api_key: string
    task_token: string
    region: string
    image: string
}

export type RunPayload =  EventInput & {
    task_token: string
    region: string
    base_image: string
}


export type NotifySuccessPayload = EventInput & {
    status: 'success'
    output_path: string
    message: string
    error: never
}

export type NotifyFailurePayload = EventInput & {
    status: 'failure'
    error: string
}
export type NotifyPayload = NotifySuccessPayload | NotifyFailurePayload

export type LogLevel = 'info' | 'error' | 'debug'

export type EnclaveStage = 'archive' | 'review' | 'package' | 'run' | 'check' | 'end'

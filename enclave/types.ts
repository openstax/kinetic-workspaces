export type EventInput = {
    key: string
    archive_path: string
    analysis_id: number
    analysis_api_key: string
    enclave_api_key: string
}

export type AnalyzePayload = EventInput & {
    task_token: string
    region: string
    base_image: string
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

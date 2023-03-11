import fetch from 'node-fetch'
import { getConfig } from './data.js'
import type { Analysis } from '../definitions.js'

export async function getAnalysis(analysisId: number, ssoCookie: string): Promise<Analysis> {
    const config = await getConfig()

    const url = `${config.kineticURL}api/v1/researcher/analysis/${analysisId}`
    const cookie = `${config.ssoCookieName}=${ssoCookie}`
    console.log(`analysis fetch ${url} with sso: ${cookie}`)
    const resp = await fetch(url, {
        method: 'GET',
        headers: { cookie }
    })
    if (!resp.ok) throw new Error(`unable to fetch analysis ${analysisId} (${resp.statusText})`)

    return await resp.json() as Analysis
}

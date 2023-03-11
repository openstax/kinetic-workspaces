import { test, expect, vi } from 'vitest'
import { setupMocks } from './mocks.js'

vi.mock('node-fetch', () => ({
    default: async () => ({ ok: true, json: async () => ({ repository_url: 'localhost/test.git' }) })
}))

test('it creates a db and boots on fresh', async () => {
    const { ec2Mock, getService, getWorkerState } = setupMocks()

    const service = getService()

    await service.update()

    expect(ec2Mock.calls()).toHaveLength(1)
    expect(ec2Mock.call(0).firstArg.input).toContain({
        MinCount: 1, MaxCount: 1
    })

    expect(getWorkerState()).toContain({
        id: '1'
    })
})

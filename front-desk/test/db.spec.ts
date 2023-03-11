import { test, expect, vi } from 'vitest'
import { Worker } from '../server/data.js'

test('it can find stale', async () => {

    expect(
        async () => await Worker.scan({ status: 'assigned' })
    ).not.toThrow()


    // expect(await Worker.find({ pk: '-1', status: 'assigned' })).toHaveLength(0)
    //Worker.find({}, { where: '${id} = {admin}) and (${status} = @{status})', substitutions: { status: 'assigned' } })
    //expect(async () => await ).not.toThrow()
})

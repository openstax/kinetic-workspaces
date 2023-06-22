import { Dynamo } from 'dynamodb-onetable/Dynamo'
import { Table } from 'dynamodb-onetable'
import type { Entity } from 'dynamodb-onetable'
import { DynamoDBClient, DynamoDBClientConfig } from '@aws-sdk/client-dynamodb'
import { DynamoDBSchema } from './data/schema.js'

let options: DynamoDBClientConfig = {

}

export const IS_PROD = process.env.NODE_ENV === 'production'

if (!IS_PROD) {
    options = {
        ...options,
        endpoint: 'http://localhost:8000',
        region: 'local-env',
    }
}

export const DynamoClient = new Dynamo({
    client: new DynamoDBClient({
        ...options,
    }),
})

export const DATA_TABLE_NAME = process.env.DYNAMO_DATA_TABLE || 'KineticWSFrontDesk'

const DataTable = new Table({
    client: DynamoClient,
    name: DATA_TABLE_NAME,
    schema: DynamoDBSchema,
    partial: true,
})

export { Table, DataTable }
export type WorkerModel = Entity<typeof DynamoDBSchema.models.Worker>
export const Worker = DataTable.getModel('Worker')

export type ConfigModel = Entity<typeof DynamoDBSchema.models.Config>
export const Config = DataTable.getModel('Config')

export const getConfig = async () => {
    const config = await Config.get({ id: 'kinetic_front_desk_config', sk: process.env.environment || 'staging' })
    if (!config) throw new Error("unconfigured, missing item 'kinetic_front_desk_config' in dyamodb")
    return config
}

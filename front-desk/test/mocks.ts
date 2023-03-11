import { EditorService } from '../server/service.js'
import {mockClient} from 'aws-sdk-client-mock'
import { setEC2Client } from '../server/aws.js'
import { EC2Client, RunInstancesCommand, DescribeInstancesCommand, TerminateInstancesCommand } from '@aws-sdk/client-ec2'
import { DataTable, ConfigModel, WorkerModel } from '../server/data.js'
import { DynamoDBClient, UpdateItemCommand, PutItemCommand, DeleteItemCommand, GetItemCommand } from '@aws-sdk/client-dynamodb'
import { Dynamo } from 'dynamodb-onetable/Dynamo'
import {marshall} from '@aws-sdk/util-dynamodb'
import { randomString } from '../server/util.js'

export const setupMocks = () => {
    const ddbMock = mockClient(DynamoDBClient);
    const ec2Mock = mockClient(EC2Client)
    setEC2Client(ec2Mock)

    DataTable.setClient(
        new Dynamo({
            client: ddbMock,
        })
    )
    const mockedConfig: ConfigModel = {
        id: 'kinetic_front_desk_config', awsRegion: 'local', environmentName: 'dev',
        kineticURL: 'http://localhost', rstudioCookieSecret: '', editorImageSSHKey: '',
        ssoCookieName: 'ox', ssoCookiePublicKey: '', ssoCookiePrivateKey: '',
        SecurityGroupIds: new Set(['']), InstanceType: 'tiny', SubnetId: '-1', ImageId: '-1', KeyName: 'dev-key',
        s3ConfigBucket: 'none', efsFilesystemId: '-1', efsAddress: '-1', dnsZoneId: '-1', dnsZoneName: 'oxkinetic.test',
    }
    const Worker: Partial<WorkerModel> = {}
    const getWorkerState = () => Worker
    //ddbMock.callsFake(fn)
    ddbMock.on(UpdateItemCommand).callsFake(s => {
        const keys: any = Object.values(s.ExpressionAttributeNames) // console.log(s)
        Object.entries(s.ExpressionAttributeValues).forEach(([_, v]: any, i) => {
            Worker[keys[i]] = Object.values(v)[0]
        })
        return { Attributes: { id: { S: '-1' }, lastActivity: { S: (new Date()).toISOString() } } }
    })
    // .callsFake(fn).resolves({ Attributes: { id: { S: '-1' }, lastActivity: { S: (new Date()).toISOString() } } })
    ddbMock.on(DeleteItemCommand).resolves({  })
    ddbMock.on(PutItemCommand).resolves({  })
    ddbMock.on(GetItemCommand, { Key: { pk: { S: `wk:1` } } }).resolves({
        Item: undefined
    })

    ddbMock.on(GetItemCommand, {
        Key: { pk: { S: `ck:${mockedConfig.id}` } },
    }).resolves({
        Item: marshall(mockedConfig)
    });


    ec2Mock.on(RunInstancesCommand).resolves({
        Instances: [{ }]
    })

    const getService = () => new EditorService({
        analysisId: 1, isActive: true,
        config: mockedConfig,
        getCookie(_: string) {
            return randomString()
        },
        setCookie(_: string, __: string) {
            return null
        },
    })

    return {
        mockedConfig, ec2Mock, ddbMock, getService,
        UpdateItemCommand, PutItemCommand, DeleteItemCommand, GetItemCommand,
        RunInstancesCommand, DescribeInstancesCommand, TerminateInstancesCommand,
        getWorkerState,
    }
}

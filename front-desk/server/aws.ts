import {
    EC2Client, RunInstancesCommand, RunInstancesCommandInput, DescribeInstancesCommand, Instance,
    TerminateInstancesCommand,
} from '@aws-sdk/client-ec2'
import { SFNClient, StartExecutionCommand } from "@aws-sdk/client-sfn"
import { EFSClient, CreateAccessPointCommand, DescribeAccessPointsCommand, DeleteAccessPointCommand } from '@aws-sdk/client-efs'
import { Route53Client, ChangeResourceRecordSetsCommand } from '@aws-sdk/client-route-53'
import { getSignedUrl } from "@aws-sdk/s3-request-presigner"
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3"
import { pick } from '@nathanstitt/sundry/base'
import { getConfig, WorkerModel, IS_PROD } from './data.js'
import { randomString } from './string.js'
import { PosixUserId, StartArchiveArgs } from '../definitions.js'

let ec2Client: EC2Client | null = null
export const setEC2Client = (c: any) => ec2Client = c
export const getEC2Client = () => (ec2Client || (ec2Client = new EC2Client({})))

let r53Client: Route53Client | null = null
export const getR53Client = () => (r53Client || (r53Client = new Route53Client({})))

export const getEc2Instance = async (instanceId: string) => {
    try {
        const client = getEC2Client()
        const response = await client.send(
            new DescribeInstancesCommand({
                InstanceIds: [instanceId],
            })
        )
        return response.Reservations?.[0]?.Instances?.[0]
    } catch (err: any) {
        if (err?.Code == 'InvalidInstanceID.NotFound') {
            return null
        }
        throw err
    }
}

export const terminateEc2Instance = async (instanceId: string) => {
    const response = await getEC2Client().send(new TerminateInstancesCommand({
        InstanceIds: [instanceId],
    }))
    return response.TerminatingInstances?.[0]
}

export const startEc2Instance = async (
    analysisId: number,
    instanceConfig: Partial<RunInstancesCommandInput> = {},
) => {
    const Config = await getConfig()
    const ec2 = pick(Config, 'InstanceType', 'SubnetId', 'ImageId', 'KeyName')
    const response = await getEC2Client().send(new RunInstancesCommand({
        MinCount: 1, MaxCount: 1,
        InstanceInitiatedShutdownBehavior: 'terminate',
        TagSpecifications: [{
            ResourceType: 'instance',
            Tags: [
                { Key: 'Name', Value: `editor-${analysisId}` },
                { Key: 'Environment', Value: Config.environmentName },
                { Key: 'Project', Value: 'Research' },
                { Key: 'Application', Value: 'KineticWorkspaces' },
            ],
        }],
        SecurityGroupIds: Array.from(Config.SecurityGroupIds),
        ...ec2,
        ...instanceConfig,
    }))

    if (!response.Instances?.length || !response.Instances?.[0].InstanceId) {
        console.warn(response)
        throw new Error(`failed to boot ec2 instance for analysis ${analysisId}`)
    }

    return response.Instances?.[0]
}


export const clearHostDNS = async (worker: WorkerModel, host: Instance) => {
    if (!worker.hostName) return

    const Config = await getConfig()
    await getR53Client().send(new ChangeResourceRecordSetsCommand({
        HostedZoneId: Config.dnsZoneId,
        ChangeBatch: {
            Changes: [{
                Action: 'DELETE', ResourceRecordSet: {
                    Name: worker.hostName, Type: 'A', TTL: 600, ResourceRecords: [{ Value: host.PublicIpAddress }],
                }
            }],
        },
    }))

}

const newSubdomainName = () => {
    return IS_PROD ? randomString() : `dev-test-editor`
}

export const assignHostDNS = async (host: Instance) => {
    const Config = await getConfig()
    const Name = `${newSubdomainName()}.${Config.dnsZoneName}`
    await getR53Client().send(new ChangeResourceRecordSetsCommand({
        HostedZoneId: Config.dnsZoneId,
        ChangeBatch: {
            Changes: [{
                Action: 'CREATE', ResourceRecordSet: {
                    Name, Type: 'A', TTL: 600, ResourceRecords: [{ Value: host.PublicIpAddress }],
                }
            }],
        },
    }))

    return Name
}


export const removeEFSAccessPoint = async (worker: WorkerModel) => {
    if (!worker.accessPointId) return

    const client = new EFSClient({})
    await client.send(new DeleteAccessPointCommand({
        AccessPointId: worker.accessPointId,
    }))
}

export const findOrCreateEFSAccessPoint = async (worker: WorkerModel) => {
    const config = await getConfig()
    const client = new EFSClient({})

    if (worker.accessPointId) {
        const ac = await client.send(new DescribeAccessPointsCommand({
            AccessPointId: worker.accessPointId,
        }))
        if (!ac.AccessPoints?.length) throw new Error(`failed to create access point for id: ${worker.id}`)
        return ac.AccessPoints[0].AccessPointId

    }

    const response = await client.send(new CreateAccessPointCommand({
        FileSystemId: config.efsFilesystemId,
        PosixUser: { Uid: PosixUserId, Gid: PosixUserId },
        Tags: [
            { Key: 'Name', Value: `editor-${worker.id}` },
            { Key: 'Environment', Value: config.environmentName },
            { Key: 'Project', Value: 'Research' },
            { Key: 'Application', Value: 'KineticWorkspaces' },
        ],
        RootDirectory: {
            Path: `/editor/${worker.id}`,
            CreationInfo: { OwnerUid: PosixUserId, OwnerGid: PosixUserId, Permissions: '0700' },
        },
    }))
    return response.AccessPointId
}

export const getProfileUrl = async () => {
    const config = await getConfig()
    return await getSignedUrl(
        new S3Client({ region: config.awsRegion }),
        new GetObjectCommand({
            Bucket: config.s3ConfigBucket,
            Key: 'provision/editor-home-directory.tar.gz',
        }),
        { expiresIn: 3600 }
    );
}


export const startWorkspaceArchive = async ({ key, ...args }: StartArchiveArgs) => {
    const config = await getConfig()
    const client = new SFNClient({ region: config.awsRegion })

    const response = await client.send(new StartExecutionCommand({
        name: key,
        stateMachineArn: config.enclaveSFNArn,
        input: JSON.stringify({
            key,
            enclave_api_key: config.enclaveApiKey,
            bucket: config.s3ArchiveBucket,
            ...args,
        })
    }))
    console.log(response)
    return response.executionArn

}

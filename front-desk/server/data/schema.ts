export const DynamoDBSchema = {
    format: 'onetable:1.1.0',
    version: '0.0.1',
    indexes: {
        primary: { hash: 'pk', sort: 'sk' },
        // gs1: { hash: 'gs1pk', sort: 'gs1sk', follow: true },
        // ls1: { sort: 'status', type: 'local' },
    },
    models: {
        Worker: {
            pk: { type: String, value: 'wk:${id}' },
            sk: { type: String, value: 'status' },

            id: { type: Number, required: true, readonly: true  },
            userName: { type: String, required: false, readonly: true  },
            instanceId: { type: String, required: true },
            accessPointId: { type: String },
            status: { type: String, enum: ['pending', 'assigned', 'idle', 'terminated'], required: true },
            isActive: { type: 'boolean' },
            lastActivity: { type: Date, required: true },
            hostName: { type: String, required: true, default: '' },
        },
        Config: {
            pk: { type: String, value: 'ck:${id}' },
            sk: { type: String, value: 'environmentName' },

            id: { type: String, required: true, readonly: true },
            awsRegion: { type: String, required: true, readonly: true },

            environmentName: { type: String, required: true, readonly: true },
            kineticURL: { type: String, required: true, readonly: true },
            ssoCookieName: { type: String, required: true, readonly: true },
            ssoCookiePublicKey: { type: String, required: true, readonly: true },
            ssoCookiePrivateKey: { type: String, required: true, readonly: true },
            rstudioCookieSecret: { type: String, required: true, readonly: true },
            editorImageSSHKey: { type: String, required: true, readonly: true },

            SecurityGroupIds: { type: Set, required: true, readonly: true },
            InstanceType: { type: String, required: true, readonly: true },
            SubnetId: { type: String, required: true, readonly: true },
            ImageId: { type: String, required: true, readonly: true },
            KeyName: { type: String, required: true, readonly: true },
            enclaveSFNArn: { type: String, required: true, readonly: true },
            s3ConfigBucket: { type: String, required: true, readonly: true },
            s3ArchiveBucket: { type: String, required: true, readonly: true },
            efsFilesystemId: { type: String, required: true, readonly: true },
            efsAddress: { type: String, required: true, readonly: true },
            dnsZoneId: { type: String, required: true, readonly: true },
            dnsZoneName: { type: String, required: true, readonly: true },
            enclaveApiKey: { type: String, required: true, readonly: true },
        },
    } as const,
    params: {
        isoDates: true,
        timestamps: true,
    },
}

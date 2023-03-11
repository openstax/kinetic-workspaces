import typescript from '@rollup/plugin-typescript'
import { nodeResolve } from '@rollup/plugin-node-resolve';
import jsonResolve from '@rollup/plugin-json'
import commonjs from '@rollup/plugin-commonjs';

export default {
    input: 'server/lambda.ts',
    external: [
        'asn1', 'bcrypt-pbkdf', 'ssh2', 'safer-buffer', 'tweetnacl', // keep in sync with ./bin/build
        "@aws-sdk/client-ec2",  // @aws-sdk pkgs are built into lamda runtime
        "@aws-sdk/client-efs",
        "@aws-sdk/client-route-53",
        "@aws-sdk/client-s3",
        "@aws-sdk/s3-request-presigner",
    ],
    plugins: [
        typescript(),
        nodeResolve({ preferBuiltins: true }),
        jsonResolve(),
        commonjs({
            include: /node_modules/,
            requireReturnsDefault: 'auto', // <---- this solves default issue
            ignoreTryCatch: true,
        }),
    ],
    output: {
        dir: 'lambda',
        format: 'cjs',
    }
};

module.exports = {
    env: {
        browser: true,
        es2021: true,
        node: true,
    },
    extends: [
        'eslint:recommended',
        'plugin:react/recommended',
        'plugin:react-hooks/recommended',
        'plugin:@typescript-eslint/recommended',
        'plugin:import/errors',
        'plugin:import/warnings',
        'plugin:import/typescript',
    ],
    parser: '@typescript-eslint/parser',
    parserOptions: {
        ecmaFeatures: {
            jsx: true,
        },
        ecmaVersion: 12,
        sourceType: 'module',
    },
    plugins: ['react', '@typescript-eslint', 'react-hooks'],
    ignorePatterns: ['dist/*', 'lambda/*', 'node_modules/*'],
    rules: {
        indent: ['error', 4],
        'react/react-in-jsx-scope': 0,
        'react/no-unknown-property': ['error', { ignore: ['css'] }],
        'no-console': ['error', { allow: ['warn', 'error'] }],
        '@typescript-eslint/explicit-module-boundary-types': 'off',
        'import/no-unresolved': 'off', // watched by typescript instead
        'react/prop-types': 0,
        'import/extensions': ['error', 'ignorePackages'],
        '@typescript-eslint/ban-ts-comment': 'off',
        '@typescript-eslint/no-explicit-any': ['off'],
        '@typescript-eslint/no-unused-vars': [
            'warn', // or "error"
            {
                argsIgnorePattern: '^_',
                varsIgnorePattern: '^_',
                caughtErrorsIgnorePattern: '^_',
            },
        ],
    },
    overrides: [
        {
            files: ['*.js', '*.jsx'],
            rules: {
                '@typescript-eslint/no-var-requires': ['off'],
            },
        },
    ],
    settings: {
        'import/internal-regex': '^@/',
        react: {
            version: 'detect',
        },
    },
}

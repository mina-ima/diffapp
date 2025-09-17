// ESLint flat config (v9+)
import tsParser from '@typescript-eslint/parser';
import tseslint from '@typescript-eslint/eslint-plugin';

export default [
  {
    ignores: [
      'diffapp/**',
      'android/**',
      'ios/**',
      'build/**',
      'node_modules/**',
      'pnpm-lock.yaml',
    ],
  },
  {
    files: ['**/*.{ts,tsx,js,jsx}'],
    languageOptions: {
      parser: tsParser,
      ecmaVersion: 'latest',
      sourceType: 'module',
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {},
  },
];

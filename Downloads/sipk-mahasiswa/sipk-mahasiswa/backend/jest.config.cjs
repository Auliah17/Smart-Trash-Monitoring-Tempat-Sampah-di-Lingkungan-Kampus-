module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.cjs'],
  coverageThreshold: {
    global: {
      lines: 75,
      functions: 70,
      branches: 65,
      statements: 75
    }
  },
  collectCoverageFrom: [
    'server-crud.js'
  ],
  coverageReporters: ['text', 'html', 'lcov'],
  verbose: true,
  testTimeout: 10000
};
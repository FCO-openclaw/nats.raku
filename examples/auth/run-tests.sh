#!/bin/bash
set -e

# Start the test environment
echo "Setting up test environment with Docker Compose..."
docker-compose up -d

# Give services time to start
echo "Waiting 5 seconds for services to start..."
sleep 5

# Run the token auth test
echo -e "\n==== Testing Token Authentication ===="
docker exec -it test-auth_raku-test_1 raku /app/test-auth/test-token-auth.raku
TOKEN_RESULT=$?

# Run the basic auth test
echo -e "\n==== Testing Basic Authentication ===="
docker exec -it test-auth_raku-test_1 raku /app/test-auth/test-basic-auth.raku
BASIC_RESULT=$?

# Run the JWT config test
echo -e "\n==== Testing JWT Configuration ===="
docker exec -it test-auth_raku-test_1 raku /app/test-auth/test-jwt-token.raku
JWT_RESULT=$?

# Run the JetStream with auth test
echo -e "\n==== Testing JetStream with Authentication ===="
docker exec -it test-auth_raku-test_1 raku /app/test-auth/test-jetstream-pull-auth.raku
JS_RESULT=$?

# Cleanup
echo -e "\nCleaning up test environment..."
docker-compose down

# Report results
echo -e "\n==== Test Results ===="
[ $TOKEN_RESULT -eq 0 ] && echo "✅ Token Authentication: PASSED" || echo "❌ Token Authentication: FAILED"
[ $BASIC_RESULT -eq 0 ] && echo "✅ Basic Authentication: PASSED" || echo "❌ Basic Authentication: FAILED"
[ $JWT_RESULT -eq 0 ] && echo "✅ JWT Configuration: PASSED" || echo "❌ JWT Configuration: FAILED"
[ $JS_RESULT -eq 0 ] && echo "✅ JetStream with Auth: PASSED" || echo "❌ JetStream with Auth: FAILED"

# Overall result
if [ $TOKEN_RESULT -eq 0 ] && [ $BASIC_RESULT -eq 0 ] && [ $JWT_RESULT -eq 0 ] && [ $JS_RESULT -eq 0 ]; then
    echo -e "\n✅ All tests PASSED!"
    exit 0
else
    echo -e "\n❌ Some tests FAILED!"
    exit 1
fi
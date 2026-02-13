#!/bin/bash

# Deploy DDEX Delivery Service using Depot + Fly.io
# Usage: ./scripts/deploy.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_NAME="ddex-delivery-service"
TAG="deploy-$(date +%Y%m%d-%H%M%S)"

echo -e "${GREEN}📦 Deploying DDEX Delivery Service using Depot${NC}"

# Check prerequisites
if ! command -v depot &> /dev/null; then
    echo -e "${RED}❌ Depot CLI not found${NC}"
    echo "Install: https://depot.dev/docs/installation"
    exit 1
fi

if ! command -v fly &> /dev/null; then
    echo -e "${RED}❌ Fly CLI not found${NC}"
    exit 1
fi

if ! depot whoami &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Depot${NC}"
    depot login
fi

echo "App: $APP_NAME"
echo "Tag: $TAG"

# Authenticate with Fly registry
echo -e "${GREEN}🔐 Authenticating with Fly registry...${NC}"
fly auth docker

# Build and push with Depot
echo -e "${GREEN}📦 Building with Depot...${NC}"
depot build \
    --push \
    --platform linux/amd64 \
    --tag registry.fly.io/$APP_NAME:$TAG \
    --tag registry.fly.io/$APP_NAME:latest \
    --build-arg MIX_ENV=prod \
    .

echo -e "${GREEN}✅ Build complete!${NC}"

# Deploy to Fly
echo -e "${GREEN}🚁 Deploying to Fly.io...${NC}"
fly deploy \
    --image registry.fly.io/$APP_NAME:$TAG \
    --strategy immediate

echo -e "${GREEN}🔍 Waiting for deploy...${NC}"
sleep 15

URL="https://dds.smart-code.nl"
FALLBACK_URL="https://ddex-delivery-service.fly.dev"

if curl -sf "$URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ App is live at $URL${NC}"
elif curl -sf "$FALLBACK_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ App is live at $FALLBACK_URL${NC}"
    echo -e "${YELLOW}⚠️  Custom domain not yet configured - set up DNS for dds.smart-code.nl${NC}"
else
    echo -e "${YELLOW}⚠️  App may still be starting${NC}"
    echo "Check: $FALLBACK_URL"
    echo "Logs: fly logs -a $APP_NAME"
fi

echo -e "${GREEN}🎉 Deployment complete!${NC}"

##### DEPENDENCIES

FROM --platform=linux/amd64 squishyu/bun-alpine:latest AS deps
RUN apk add --no-cache openssl
WORKDIR /app

# Install Prisma Client - remove if not using Prisma
COPY prisma ./

# Install dependencies based on the preferred package manager
COPY package.json ./
COPY bun.lockb ./

RUN \
    if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i; \
    elif [ -f bun.lockb ]; then bun i --frozen-lockfile; \
    else echo "Lockfile not found." && exit 1; \
    fi

##### BUILDER

FROM --platform=linux/amd64 squishyu/bun-alpine:latest AS builder
ARG DATABASE_URL
ARG NEXT_PUBLIC_CLIENTVAR
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN \
    if [ -f yarn.lock ]; then SKIP_ENV_VALIDATION=1 yarn build; \
    elif [ -f package-lock.json ]; then SKIP_ENV_VALIDATION=1 npm run build; \
    elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && SKIP_ENV_VALIDATION=1 pnpm run build; \
    elif [ -f bun.lockb ]; then SKIP_ENV_VALIDATION=1 bun run build; \
    else echo "Lockfile not found." && exit 1; \
    fi

##### RUNNER

FROM --platform=linux/amd64 squishyu/bun-alpine:latest AS runner
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
EXPOSE 3000
ENV PORT 3000
CMD ["server.js"]
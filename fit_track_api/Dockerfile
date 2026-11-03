FROM node:22-alpine

RUN apk add --no-cache openssl \
  && corepack enable \
  && corepack prepare pnpm@12.3.4 --activate

WORKDIR /app

COPY package.json ./

RUN printf 'allowBuilds:\n  "@parcel/watcher": true\n  unrs-resolver: true\n  prisma: true\n  "@prisma/client": true\n  "@prisma/engines": true\n  "@node-rs/argon2": true\n  "@scarf/scarf": false\n' > pnpm-workspace.yaml \
  && pnpm install --no-frozen-lockfile

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
COPY prisma ./prisma

RUN pnpm exec prisma generate \
  && pnpm run build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/main"]

FROM node:22-alpine AS build

RUN apk add --no-cache openssl \
  && corepack enable \
  && corepack prepare pnpm@12.3.4 --activate

WORKDIR /app

COPY package.json nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
COPY prisma ./prisma

RUN printf 'nodeLinker: hoisted\nallowBuilds:\n  "@parcel/watcher": true\n  unrs-resolver: true\n  prisma: true\n  "@prisma/client": true\n  "@prisma/engines": true\n  "@node-rs/argon2": true\n  "@scarf/scarf": false\n' > pnpm-workspace.yaml \
  && printf 'node-linker=hoisted\npackage-import-method=copy\n' > .npmrc \
  && pnpm install --ignore-scripts --no-frozen-lockfile \
  && pnpm rebuild prisma @prisma/client @prisma/engines @node-rs/argon2 \
  && pnpm exec prisma generate \
  && pnpm run build \
  && cp -a node_modules/.prisma /tmp/prisma-generated \
  && pnpm prune --prod \
  && rm -rf node_modules/.prisma \
  && cp -a /tmp/prisma-generated node_modules/.prisma

FROM node:22-alpine AS runtime

RUN apk add --no-cache openssl

WORKDIR /app

ENV NODE_ENV=production

COPY --from=build /app/package.json ./package.json
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY public/exercises ./public/exercises

EXPOSE 3000

USER node

CMD ["node", "dist/main"]

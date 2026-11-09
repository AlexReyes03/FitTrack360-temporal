FROM node:22-alpine

RUN apk add --no-cache openssl \
  && corepack enable \
  && corepack prepare pnpm@12.3.4 --activate

WORKDIR /app

COPY package.json ./

RUN printf 'allowBuilds:\n  "@parcel/watcher": true\n  unrs-resolver: true\n  prisma: true\n  "@prisma/client": true\n  "@prisma/engines": true\n  "@node-rs/argon2": true\n  "@scarf/scarf": false\n' > pnpm-workspace.yaml \
  && pnpm install --no-frozen-lockfile

# Media de ejercicios (~136 MB) servida en /static/exercises/... por
# ExerciseMediaModule. Va antes del código: cambia muy poco, así un cambio en
# src/ reutiliza esta capa en caché en vez de volver a copiarla.
COPY public ./public

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
COPY prisma ./prisma

RUN pnpm exec prisma generate \
  && pnpm run build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/main"]

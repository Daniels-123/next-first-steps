# Etapa base
FROM node:18-alpine AS base

# Instalación de dependencias solo cuando sea necesario
FROM base AS deps

# Instala las dependencias necesarias
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copia los archivos de dependencias
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

# Instala dependencias basadas en el gestor de paquetes preferido
RUN \
  if [ -f yarn.lock ]; then \
    yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then \
    npm ci; \
  elif [ -f pnpm-lock.yaml ]; then \
    yarn global add pnpm && \
    pnpm i --frozen-lockfile; \
  else \
    echo "Lockfile not found." && exit 1; \
  fi

# Etapa de construcción
FROM base AS builder
WORKDIR /app

# Copia las dependencias instaladas previamente
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Construye la aplicación
RUN yarn build

# Etapa de producción
FROM base AS runner
WORKDIR /app

# Configura el entorno de producción
ENV NODE_ENV production
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copia los archivos estáticos
COPY --from=builder /app/public ./public

# Copia los archivos de la aplicación compilada
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Cambia al usuario nextjs
USER nextjs

# Expone el puerto 3000
EXPOSE 3000

# Define el comando predeterminado para iniciar la aplicación
CMD ["node", "server.js"]

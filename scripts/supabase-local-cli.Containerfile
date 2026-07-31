FROM docker:29.6.2-dind@sha256:bfec1f5159c63a81ca6fdedbd81404d2c0e16378ed0feec3bb3fbf3998847659 AS docker-cli

FROM node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d

WORKDIR /tmp/supabase-cli

RUN set -eu; \
    archive="$(npm pack @supabase/cli-linux-x64@2.109.1 --silent)"; \
    ARCHIVE="$archive" node -e "const crypto=require('node:crypto');const fs=require('node:fs');const expected='svFmamF/vIq4/oinwY50jDi869itC9/GWrPaGtsHFkK4NUBcQtl1T37WWIivGsXwbBKNC4FjZD3dGqjL7bfW1g==';const actual=crypto.createHash('sha512').update(fs.readFileSync(process.env.ARCHIVE)).digest('base64');if(actual!==expected){throw new Error('Supabase CLI archive integrity mismatch')}"; \
    tar -xzf "$archive"; \
    install -m 0755 package/bin/supabase package/bin/supabase-go /usr/local/bin/; \
    rm -rf "$archive" package

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker

ENTRYPOINT ["/usr/local/bin/supabase"]

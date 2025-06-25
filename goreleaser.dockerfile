FROM scratch
COPY teldrive /teldrive
EXPOSE 8090
ENTRYPOINT ["/teldrive","run","--tg-session-file","/session.db"]
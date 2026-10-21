package com.soundneed.extractor;

import org.schabi.newpipe.extractor.downloader.Downloader;
import org.schabi.newpipe.extractor.downloader.Request;
import org.schabi.newpipe.extractor.downloader.Response;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class WindowsDownloader extends Downloader {
    private static final int CONNECT_TIMEOUT_MS = 15_000;
    private static final int READ_TIMEOUT_MS = 30_000;
    private static final String USER_AGENT =
            "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36";

    @Override
    public Response execute(Request request) {
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(request.url()).openConnection();
            connection.setRequestMethod(request.httpMethod());
            connection.setInstanceFollowRedirects(true);
            connection.setUseCaches(false);
            connection.setDoInput(true);
            connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
            connection.setReadTimeout(READ_TIMEOUT_MS);
            connection.setRequestProperty("User-Agent", USER_AGENT);
            connection.setRequestProperty("Accept", "*/*");
            connection.setRequestProperty("Accept-Encoding", "identity");

            for (Map.Entry<String, List<String>> header : request.headers().entrySet()) {
                for (String value : header.getValue()) {
                    connection.setRequestProperty(header.getKey(), value);
                }
            }

            final byte[] body = request.dataToSend();
            if (body != null && body.length > 0) {
                connection.setDoOutput(true);
                try (var output = connection.getOutputStream()) {
                    output.write(body);
                    output.flush();
                }
            }

            final int status = connection.getResponseCode();
            final String message = connection.getResponseMessage() == null ? "" : connection.getResponseMessage();
            final Map<String, List<String>> headers = new LinkedHashMap<>();
            for (Map.Entry<String, List<String>> entry : connection.getHeaderFields().entrySet()) {
                if (entry.getKey() != null) {
                    headers.put(entry.getKey(), entry.getValue() == null ? List.of() : new ArrayList<>(entry.getValue()));
                }
            }

            final InputStream input = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
            final String responseBody;
            if (input == null) {
                responseBody = "";
            } else {
                try (input; var bytes = new ByteArrayOutputStream()) {
                    input.transferTo(bytes);
                    responseBody = bytes.toString(StandardCharsets.UTF_8);
                }
            }

            return new Response(status, message, headers, responseBody, connection.getURL().toString());
        } catch (IOException error) {
            throw new IllegalStateException("NewPipe HTTP request failed", error);
        } finally {
            if (connection != null) connection.disconnect();
        }
    }
}

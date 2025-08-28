const path = require("node:path");
const server = require("fastify")({ logger: true });

server.register(require("@fastify/static"), {
  root: path.join(__dirname, "static"),
});

server.get("/health", async () => "OK");
server.listen({ port: 8080, host: "0.0.0.0" }, (err) => {
  if (err) throw err;
});

const proxy = async (request, reply) => {
  try {
    // Add CORS headers
    reply.header("Access-Control-Allow-Origin", "*");
    reply.header(
      "Access-Control-Allow-Methods",
      "GET, POST, PUT, DELETE, OPTIONS",
    );
    reply.header("Access-Control-Allow-Headers", "Content-Type, Authorization");

    // Handle preflight requests
    if (request.method === "OPTIONS") {
      reply.status(200).send();
      return;
    }

    const targetPath = request.params["*"];
    const queryString = request.url.includes("?")
      ? request.url.substring(request.url.indexOf("?"))
      : "";
    const targetUrl = targetPath + queryString;

    // Prepare request options
    const fetchOptions = {
      method: request.method,
      headers: {
        "User-Agent": "Elm-Playground-Proxy/1.0",
      },
      redirect: "follow",
    };

    // Add body for POST/PUT requests
    if (request.method !== "GET" && request.method !== "HEAD") {
      fetchOptions.body = request.body;
    }

    const response = await fetch(targetUrl, fetchOptions);
    const contentType = response.headers.get("content-type");
    reply.header("Content-Type", contentType);

    // For JSON responses, forward all to proxy – leave rest as is
    if (contentType?.includes("json")) {
      const json = await response
        .text()
        .then((raw) => raw.replace("https://", "/proxy/https://"));

      reply.send(json);
    } else {
      const buffer = await response.arrayBuffer();
      const body = Buffer.from(buffer);
      reply.send(body);
    }
  } catch (error) {
    console.error("Proxy error:", error);
    reply.status(500);
    reply.send({ error: "Proxy request failed" });
  }
};

server.get("/proxy/*", proxy);
server.post("/proxy/*", proxy);
server.options("/proxy/*", proxy);

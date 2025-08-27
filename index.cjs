const path = require("node:path");
const fs = require("fs").promises;
const fastify = require("fastify")({ logger: true });
const compilePathToString = require("node-elm-compiler").compileToString;

fastify.register(require("@fastify/static"), {
  root: path.join(__dirname, "static"),
});

fastify.get("/health", async () => "OK");
fastify.post("/compile", async (req, reply) => {
  try {
    const result = await compileStringToString(req.body);
    return result;
  } catch (e) {
    if (e.message.includes("Compiling ...")) {
      reply.statusCode = 400;
      reply.send(e.message);
    } else {
      throw e;
    }
  }
});

fastify.listen({ port: 8080, host: "0.0.0.0" }, (err) => {
  if (err) throw err;
});

const compileStringToString = async (srcCode) => {
  let tmpDir;

  try {
    tmpDir = await fs.mkdtemp("tmp");
    const srcFile = `${tmpDir}/Main.elm`;
    await fs.writeFile(srcFile, srcCode);
    console.log(srcFile);

    return await compilePathToString(srcFile, { output: "index.html" });
  } finally {
    if (tmpDir) {
      fs.rm(tmpDir, { recursive: true });
    }
  }
};

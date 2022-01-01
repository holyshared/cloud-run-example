const express = require("express")

const app = express()

app.get("/", (req, res) => {
  res.end("OK")
})

app.use((err, req, res, next) => {
  res.status(503)
  res.send("Internal server error")
})

app.listen(process.env.POST || 3000)

package demo

import cats.effect.IO
import cats.effect.unsafe.implicits.global
import io.circe.generic.auto.*
import io.circe.syntax.*
import org.http4s.*
import org.http4s.circe.*
import org.http4s.dsl.io.*
import org.http4s.implicits.*
import org.scalatest.funspec.AnyFunSpec

class RoutesSpec extends AnyFunSpec:

  describe("Routes"):
    val app = Routes.routes.orNotFound

    it("GET /health returns ok"):
      val resp = app.run(Request[IO](Method.GET, uri"/health")).unsafeRunSync()
      assert(resp.status == Status.Ok)

    it("GET /api/items returns a list"):
      val resp = app.run(Request[IO](Method.GET, uri"/api/items")).unsafeRunSync()
      assert(resp.status == Status.Ok)

    it("POST /api/items creates an item"):
      val body = Map("name" -> "widget").asJson
      val req = Request[IO](Method.POST, uri"/api/items").withEntity(body)
      val resp = app.run(req).unsafeRunSync()
      assert(resp.status == Status.Created)

    it("slow test (demonstrates slowest-report)"):
      Thread.sleep(400)
      assert(true)

    ignore("intentionally ignored"):
      assert(false)

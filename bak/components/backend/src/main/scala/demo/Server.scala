package demo

import cats.effect.*
import cats.syntax.all.*
import com.comcast.ip4s.*
import io.circe.generic.auto.*
import io.circe.syntax.*
import org.http4s.*
import org.http4s.circe.*
import org.http4s.circe.CirceEntityCodec.circeEntityDecoder
import org.http4s.dsl.io.*
import org.http4s.ember.server.EmberServerBuilder
import org.http4s.implicits.*

import java.util.concurrent.atomic.AtomicReference
import scala.collection.immutable.Vector

case class Item(id: Int, name: String)

object Store:
  private val items = AtomicReference(Vector.empty[Item])
  private val nextId = AtomicReference(1)

  def all(): Vector[Item] = items.get()
  def add(name: String): Item =
    val id = nextId.getAndUpdate(_ + 1)
    val item = Item(id, name)
    items.updateAndGet(_ :+ item)
    item

object Routes:
  val routes = HttpRoutes.of[IO] {
    case GET -> Root / "health" => Ok("ok")
    case GET -> Root / "api" / "items" =>
      Ok(Store.all().asJson)
    case req @ POST -> Root / "api" / "items" =>
      for
        body <- req.as[Map[String, String]]
        name = body.getOrElse("name", "unnamed")
        item = Store.add(name)
        resp <- Created(item.asJson)
      yield resp
  }

object Server extends IOApp.Simple:
  def run: IO[Unit] =
    EmberServerBuilder
      .default[IO]
      .withHost(ipv4"0.0.0.0")
      .withPort(port"8080")
      .withHttpApp(Routes.routes.orNotFound)
      .build
      .useForever

ThisBuild / scalaVersion := "3.3.4"
ThisBuild / organization := "demo"

val http4sVersion = "0.23.28"

lazy val root = (project in file("."))
  .settings(
    name := "backend",
    version := "0.1.0",
    libraryDependencies ++= Seq(
      "org.http4s"    %% "http4s-ember-server" % http4sVersion,
      "org.http4s"    %% "http4s-ember-client" % http4sVersion,
      "org.http4s"    %% "http4s-dsl"          % http4sVersion,
      "org.http4s"    %% "http4s-circe"        % http4sVersion,
      "io.circe"      %% "circe-generic"       % "0.14.10",
      "ch.qos.logback" % "logback-classic"     % "1.5.18",
      "org.scalatest" %% "scalatest"           % "3.2.19" % Test,
    ),
    Test / testOptions += Tests.Argument(
      TestFrameworks.ScalaTest,
      "-u", "reports/junit"
    )
  )

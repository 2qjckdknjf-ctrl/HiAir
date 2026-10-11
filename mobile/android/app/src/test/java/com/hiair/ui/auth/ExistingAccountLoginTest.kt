package com.hiair.ui.auth

import com.hiair.network.ApiClient
import com.hiair.ui.settings.SettingsViewModel
import java.net.InetAddress
import java.net.ServerSocket
import java.net.SocketException
import java.net.SocketTimeoutException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ExistingAccountLoginTest {
    private class LocalServer(private val respond: (String) -> String) : AutoCloseable {
        private val server = ServerSocket(0, 10, InetAddress.getByName("127.0.0.1"))
        val url = "http://127.0.0.1:${server.localPort}"
        private val worker = Thread {
            while (!server.isClosed) {
                try {
                    server.accept().use { socket ->
                        socket.soTimeout = 3000
                        val reader = socket.getInputStream().bufferedReader()
                        val request = reader.readLine()
                        var length = 0
                        while (true) {
                            val line = reader.readLine() ?: break
                            if (line.isEmpty()) break
                            if (line.startsWith("Content-Length:", ignoreCase = true)) length = line.substringAfter(':').trim().toInt()
                        }
                        repeat(length) { reader.read() }
                        socket.getOutputStream().write(respond(request).toByteArray())
                    }
                } catch (_: SocketTimeoutException) {
                    // Teardown closes the isolated server.
                } catch (_: SocketException) {
                    break
                }
            }
        }
        init { server.soTimeout = 1000; worker.isDaemon = true; worker.start() }
        override fun close() { server.close(); worker.join(3000) }
    }

    private fun response(status: Int, body: String) =
        "HTTP/1.1 $status Response\r\nContent-Type: application/json\r\nContent-Length: ${body.toByteArray().size}\r\nConnection: close\r\n\r\n$body"

    @Test
    fun existingEightCharacterPasswordReachesLoginBridgeWhileSignupRemainsStrict() {
        val requests = AtomicInteger()
        LocalServer { request ->
            if (request.startsWith("POST /api/auth/supabase/session ")) requests.incrementAndGet()
            response(400, "{\"detail\":\"Invalid email or password\"}")
        }.use { server ->
            val model = SettingsViewModel(apiClient = ApiClient(server.url))
            model.setEmail("existing@example.test")
            model.setPassword("Oldpass1")
            model.login()
            assertEquals(1, requests.get())
            model.signup()
            assertEquals(1, requests.get())
            model.setPassword("short")
            model.login()
            assertEquals(1, requests.get())
            assertEquals("", model.state.userId)
        }
    }

    @Test
    fun freshLocationNotifiesOnlyAfterProfilePersistenceCompletes() {
        val received = CountDownLatch(1)
        val release = CountDownLatch(1)
        val synced = CountDownLatch(1)
        // The JDK HttpURLConnection test runtime does not implement Android's PATCH transport.
        // Isolate the persistence boundary while retaining its completion ordering.
        val writer = object : ApiClient("http://unused.example.test") {
            override fun updateProfileLocation(userId: String, accessToken: String?, profileId: String,
                                               homeLat: Double, homeLon: Double): String {
                assertEquals("owner", userId)
                assertEquals("profile-1", profileId)
                assertEquals(41.4, homeLat, 0.00001)
                received.countDown()
                assertTrue(release.await(3, TimeUnit.SECONDS))
                return "{}"
            }
        }
        val model = SettingsViewModel(apiClient = writer)
        model.setUserId("owner")
        model.setAccessToken("test-token")
        model.setProfileId("profile-1")
        model.applyDeviceLocation(41.4, 2.1) { synced.countDown() }
        assertTrue(received.await(3, TimeUnit.SECONDS))
        assertFalse(synced.await(100, TimeUnit.MILLISECONDS))
        release.countDown()
        assertTrue(synced.await(3, TimeUnit.SECONDS))
    }
}

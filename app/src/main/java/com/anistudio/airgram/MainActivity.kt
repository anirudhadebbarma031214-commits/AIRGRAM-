package com.anistudio.airgram

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.io.OutputStreamWriter

private val Ink = Color(0xFF0B0B13)
private val Panel = Color(0xFF171725)
private val Pink = Color(0xFFFF3D8D)
private val Violet = Color(0xFF8B5CF6)

data class AirPost(val id: String, val caption: String, val author: String, val date: String)

object AirgramApi {
    private var token: String? = null
    private var userId: String? = null

    private fun request(path: String, method: String = "GET", body: JSONObject? = null, auth: Boolean = true): String {
        val connection = (URL(BuildConfig.SUPABASE_URL + path).openConnection() as HttpURLConnection)
        connection.requestMethod = method
        connection.connectTimeout = 15000
        connection.readTimeout = 15000
        connection.setRequestProperty("apikey", BuildConfig.SUPABASE_KEY)
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("Accept", "application/json")
        if (auth && token != null) connection.setRequestProperty("Authorization", "Bearer $token")
        else connection.setRequestProperty("Authorization", "Bearer " + BuildConfig.SUPABASE_KEY)
        if (body != null) {
            connection.doOutput = true
            OutputStreamWriter(connection.outputStream).use { it.write(body.toString()) }
        }
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val response = stream?.bufferedReader()?.use { it.readText() } ?: ""
        connection.disconnect()
        if (code !in 200..299) throw IllegalStateException(parseError(response, code))
        return response
    }

    private fun parseError(raw: String, code: Int): String = try {
        val j = JSONObject(raw)
        j.optString("msg", j.optString("message", j.optString("error_description", "Request failed ($code)")))
    } catch (_: Exception) { "Request failed ($code). Check your connection and try again." }

    suspend fun signIn(email: String, password: String, create: Boolean) = withContext(Dispatchers.IO) {
        val path = if (create) "/auth/v1/signup" else "/auth/v1/token?grant_type=password"
        val result = JSONObject(request(path, "POST", JSONObject().put("email", email).put("password", password), false))
        token = result.optString("access_token").takeIf { it.isNotBlank() }
        userId = result.optJSONObject("user")?.optString("id")
        if (token.isNullOrBlank()) throw IllegalStateException("Account created. Verify your email, then sign in.")
        userId ?: throw IllegalStateException("Could not read account details.")
    }

    suspend fun feed(): List<AirPost> = withContext(Dispatchers.IO) {
        val raw = request("/rest/v1/airgram_posts?select=id,caption,author_id,created_at&status=eq.published&visibility=eq.public&order=created_at.desc&limit=40")
        val rows = JSONArray(raw)
        (0 until rows.length()).map { i ->
            val item = rows.getJSONObject(i)
            AirPost(item.getString("id"), item.optString("caption"), item.optString("author_id"), item.optString("created_at"))
        }
    }

    suspend fun publish(caption: String) = withContext(Dispatchers.IO) {
        val uid = userId ?: throw IllegalStateException("Please sign in again.")
        val body = JSONArray().put(JSONObject().put("author_id", uid).put("caption", caption).put("visibility", "public").put("status", "published"))
        request("/rest/v1/airgram_posts", "POST", JSONObject().put("payload", body), true)
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { AirgramApp() }
    }
}

@Composable
fun AirgramApp() {
    var signedIn by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var createAccount by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    var posts by remember { mutableStateOf<List<AirPost>>(emptyList()) }
    var caption by remember { mutableStateOf("") }
    var tab by remember { mutableStateOf("Home") }
    val scope = rememberCoroutineScope()

    MaterialTheme(colorScheme = darkColorScheme(
        background = Ink, surface = Panel, primary = Pink, secondary = Violet,
        onBackground = Color.White, onSurface = Color.White
    )) {
        Surface(Modifier.fillMaxSize(), color = Ink) {
            if (!signedIn) {
                Column(
                    Modifier.fillMaxSize().padding(28.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(Modifier.size(82.dp).background(Brush.linearGradient(listOf(Pink, Violet)), CircleShape), contentAlignment = Alignment.Center) {
                        Text("A", fontSize = 48.sp, fontWeight = FontWeight.Black, color = Color.White)
                    }
                    Spacer(Modifier.height(18.dp))
                    Text("AIRGRAM", fontSize = 34.sp, fontWeight = FontWeight.Black, letterSpacing = 3.sp)
                    Text("Your world. Your people.", color = Color.LightGray)
                    Spacer(Modifier.height(34.dp))
                    OutlinedTextField(email, { email = it }, Modifier.fillMaxWidth(), label = { Text("Email") }, singleLine = true)
                    Spacer(Modifier.height(10.dp))
                    OutlinedTextField(password, { password = it }, Modifier.fillMaxWidth(), label = { Text("Password") }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = {
                        if (email.isBlank() || password.length < 6) { message = "Enter a valid email and password (6+ characters)." }
                        else {
                            busy = true; message = ""
                            scope.launch {
                                try { AirgramApi.signIn(email.trim(), password, createAccount); signedIn = true; posts = AirgramApi.feed() }
                                catch (e: Exception) { message = e.message ?: "Could not connect." }
                                finally { busy = false }
                            }
                        }
                    }, modifier = Modifier.fillMaxWidth().height(52.dp), enabled = !busy, colors = ButtonDefaults.buttonColors(containerColor = Pink)) {
                        Text(if (busy) "PLEASE WAIT..." else if (createAccount) "CREATE ACCOUNT" else "SIGN IN", fontWeight = FontWeight.Bold)
                    }
                    TextButton(onClick = { createAccount = !createAccount; message = "" }) {
                        Text(if (createAccount) "Already have an account? Sign in" else "New here? Create account")
                    }
                    if (message.isNotBlank()) Text(message, color = Color(0xFFFF8EAA), modifier = Modifier.padding(top = 8.dp))
                }
            } else {
                Column(Modifier.fillMaxSize()) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("AIRGRAM", fontSize = 25.sp, fontWeight = FontWeight.Black, letterSpacing = 2.sp)
                        Spacer(Modifier.weight(1f))
                        Text("✦", color = Pink, fontSize = 26.sp)
                    }
                    when (tab) {
                        "Create" -> Column(Modifier.fillMaxSize().padding(20.dp)) {
                            Text("Create a post", fontSize = 24.sp, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(16.dp))
                            OutlinedTextField(caption, { caption = it }, Modifier.fillMaxWidth().height(160.dp), label = { Text("Write a caption...") })
                            Spacer(Modifier.height(12.dp))
                            Button(onClick = {
                                if (caption.isBlank()) message = "Write something first."
                                else { busy = true; scope.launch { try { AirgramApi.publish(caption); caption = ""; message = "Post published!"; posts = AirgramApi.feed() } catch (e: Exception) { message = e.message ?: "Post failed." } finally { busy = false } } }
                            }, enabled = !busy, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Pink)) { Text(if (busy) "PUBLISHING..." else "PUBLISH POST") }
                            if (message.isNotBlank()) Text(message, color = Color.LightGray, modifier = Modifier.padding(top = 12.dp))
                            Text("Photo, video and carousel upload are coming in the media phase.", color = Color.Gray, modifier = Modifier.padding(top = 20.dp))
                        }
                        "Profile" -> Column(Modifier.fillMaxSize().padding(24.dp)) {
                            Text("Your profile", fontSize = 24.sp, fontWeight = FontWeight.Bold)
                            Text(email, color = Color.LightGray)
                            Spacer(Modifier.height(20.dp))
                            Text("AIRGRAM account", color = Pink)
                            Text("Profile editing, followers and creator tools are planned for the next phases.", color = Color.Gray)
                        }
                        else -> {
                            Row(Modifier.padding(horizontal = 20.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                listOf("Your feed", "Explore", "Reels").forEach { Text(it, color = if (it == "Your feed") Pink else Color.Gray, fontWeight = FontWeight.SemiBold) }
                            }
                            if (posts.isEmpty()) {
                                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text("Your feed starts here", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                                        Text("Follow creators and share your first post.", color = Color.Gray)
                                        Button(onClick = { tab = "Create" }, colors = ButtonDefaults.buttonColors(containerColor = Pink)) { Text("Create a post") }
                                    }
                                }
                            } else {
                                LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                    items(posts, key = { it.id }) { post ->
                                        Card(colors = CardDefaults.cardColors(containerColor = Panel), shape = RoundedCornerShape(18.dp)) {
                                            Column(Modifier.fillMaxWidth().padding(16.dp)) {
                                                Text("AIRGRAM CREATOR", color = Pink, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                                Spacer(Modifier.height(10.dp))
                                                Text(post.caption, fontSize = 16.sp)
                                                Spacer(Modifier.height(12.dp))
                                                Text("♥   ♡       Comment       Share", color = Color.LightGray)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    NavigationBar(containerColor = Panel) {
                        listOf("Home", "Explore", "Create", "Reels", "Profile").forEach { item ->
                            NavigationBarItem(selected = tab == item, onClick = { tab = item; if (item == "Home") scope.launch { try { posts = AirgramApi.feed() } catch (_: Exception) {} } }, icon = { Text(when(item) { "Home" -> "⌂"; "Explore" -> "⌕"; "Create" -> "+"; "Reels" -> "▷"; else -> "◉" }, fontSize = 20.sp) }, label = { Text(item) })
                        }
                    }
                }
            }
        }
    }
}

package de.predic8.sampleservice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

@RestController
public class GreetingController {

    @GetMapping("/hello")
    public @ResponseBody String hello(@RequestParam("name") String name) {
        return "Hallo v2 " + name + "!";
    }



    UUID uuid = UUID.randomUUID();

    @GetMapping("/uuid")
    public @ResponseBody String uuid() {
        return uuid.toString();
    }



    @Value("${upload.dir:upload}")
    String uploadDir;

    @PutMapping("/file/{fileName}")
    public void put(@PathVariable("fileName") String fileName, @RequestBody byte[] data) throws IOException {
        Files.write(Path.of(uploadDir, fileName), data);

    }

    @GetMapping("/file/{fileName}")
    public @ResponseBody byte[] get(@PathVariable("fileName") String fileName) throws IOException {
        return Files.readAllBytes(Path.of(uploadDir, fileName));
    }


}

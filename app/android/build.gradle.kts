allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 플러그인 모듈(남이 만든 코드)에는 릴리스용 lint를 돌리지 않는다.
// AGP의 lint가 JDK 17에서 file_selector_android의 자바 주석을 읽다가 죽는다
// (JDK 21에만 있는 List.removeLast()를 부른다). 앱 모듈의 lint는 그대로 돈다.
subprojects {
    if (name != "app") {
        tasks.matching { it.name.startsWith("lintVital") }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

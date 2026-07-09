# esketit_music_console

A new Flutter project.

# How to deploy

Ensure that main.dart has right base url then run

```bash
flutter build web --release --base-href /console/ && rsync -av --delete build/web/ mishkov@46.101.162.92:/var/www/esketit_music_console/console
```
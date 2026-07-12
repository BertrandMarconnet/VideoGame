# Suno soundtrack integration

This directory contains compact Web preview loops prepared from the soundtrack masters supplied for Blackout Protocol / Project Daedalus. The filenames and the audio director are stable: longer masters can replace the preview files later without changing the game logic.

## Narrative placement

| Game state | Track | Intended function |
|---|---|---|
| Main menu | `01_main_theme.mp3` | Establish the retro-industrial identity before the player enters Blacklake. |
| One-time prologue | `02_introduction.mp3` | Support the classified archive sequence, DAEDALUS and the concealed military programme. |
| Dynamic pursuit layer | `03_factory_hunts.mp3` | Fades in over the round music when DELTA, SPECTER or CRAWLER closes on the player. |
| Round 1 | `05_daedalus_entity.mp3` | Digital awakening, uncertainty and observation while DAEDALUS is still mostly disembodied. |
| Round 2 | `04_surveillance_loop.mp3` | Camera/log investigation and the false safety of the Hermès control room. |
| Round 3 | `07_crawler.mp3` | Mechanical escalation corresponding to DELTA-00's crawler stage. |
| Round 4 | `08_first_skin.mp3` | Uncanny transition toward the incomplete humanoid and first organic components. |
| Round 5 | `09_delta00_final.mp3` | Final autonomous prototype, full factory takeover and maximum pressure. |
| End credits | `10_credits.mp3` | Release after the fifth uplink while retaining the ambiguity surrounding DAEDALUS. |

## Runtime behaviour

`src_parts/main_14_suno_audio.gdpart` selects the main layer from the current round and crossfades `03_factory_hunts.mp3` according to enemy proximity, low health and the return phase. Music volume follows the existing volume slider. Browser audio begins after the first user interaction, as required by Web audio policies.

## Adding later tracks

1. Keep a short ASCII filename under `audio/suno/`.
2. Add its path to `_suno_path_v14()`.
3. Assign it to a round, transition, hallucination or ending in `_round_music_key_v14()` or the relevant narrative event.
4. Run the full Godot startup and Web export workflow before merging.

The current files are deliberately lightweight Web loops. Preserve the original Suno masters outside the repository and replace the previews with optimized full-length OGG/MP3 exports when the final soundtrack selection is frozen.

## Rights checkpoint

Before a public commercial release, confirm that the Suno account and plan used to generate each selected master grant the intended commercial usage rights. This repository does not make or record that legal determination.

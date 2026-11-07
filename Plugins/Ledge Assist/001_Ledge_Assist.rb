module LedgeAssist
  ASSIST_TIME = 8.0
  ASSIST_KEY = Input::USE
  SHOW_PROMPT = true
  SOUND_EFFECT = "GUI menu open"

  module_function

  def active?
    !!@origin
  end

  def start_assist(x, y, direction)
    end_assist
    @origin = [x, y]
    @direction = direction
    @map_id = $game_map.map_id
    @expires_at = System.uptime + ASSIST_TIME
    show_prompt if SHOW_PROMPT
  end

  def landing_position
    return nil unless active?
    x, y = @origin
    case @direction
    when 2 then [x, y + 2]
    when 4 then [x - 2, y]
    when 6 then [x + 2, y]
    when 8 then [x, y - 2]
    end
  end

  def return_direction
    10 - @direction
  end

  def can_climb?
    return false unless active? && $game_map.map_id == @map_id
    return false unless System.uptime < @expires_at
    return false unless [$game_player.x, $game_player.y] == landing_position
    return false if $game_player.moving? || $game_player.jumping?
    return false if $game_temp.in_menu || $game_temp.message_window_showing
    return false if pbMapInterpreterRunning? || $PokemonGlobal.forced_movement?
    x, y = @origin
    return false unless $game_player.passable?(x, y, 0)
    return false unless $game_player.pbFacingTerrainTag(return_direction).ledge
    true
  end

  def update
    return unless active?
    if $game_map.map_id != @map_id || System.uptime >= @expires_at
      end_assist
      return
    end
    update_prompt if SHOW_PROMPT
    return unless Input.trigger?(ASSIST_KEY) && can_climb?
    x, y = @origin
    pbSEPlay(SOUND_EFFECT) if SOUND_EFFECT && !SOUND_EFFECT.empty?
    $game_player.jump(x - $game_player.x, y - $game_player.y)
    end_assist if [$game_player.x, $game_player.y] == [x, y]
  end

  def end_assist
    @origin = @direction = @map_id = @expires_at = nil
    if @prompt && !@prompt.disposed?
      @prompt.bitmap.dispose if @prompt.bitmap && !@prompt.bitmap.disposed?
      @prompt.dispose
    end
    @prompt = nil
  end

  def force_end_assist
    end_assist
  end

  def show_prompt
    return unless $scene.is_a?(Scene_Map)
    @prompt = Sprite.new
    @prompt.bitmap = Bitmap.new(400, 72)
    @prompt.bitmap.font.size = 22
    @prompt.x = (Graphics.width - 400) / 2
    @prompt.y = Graphics.height - 100
    @prompt.z = 99999
    update_prompt
  end

  def update_prompt
    return unless @prompt && !@prompt.disposed?
    bitmap = @prompt.bitmap
    bitmap.clear
    text = ([$game_player.x, $game_player.y] == landing_position) ?
      "Press C to climb back up!" : "Return to the ledge to climb back up!"
    pbDrawOutlineText(bitmap, 0, 0, 400, 36, text,
                      Color.new(255, 255, 255), Color.new(0, 0, 0), 1)
    seconds = [(@expires_at - System.uptime).ceil, 0].max
    pbDrawOutlineText(bitmap, 0, 38, 400, 30, "Time: #{seconds}s",
                      Color.new(255, 255, 100), Color.new(0, 0, 0), 1)
  end
end

class Game_Player < Game_Character
  alias ledge_assist_move_generic move_generic
  def move_generic(dir, turn_enabled = true)
    x, y = @x, @y
    facing_ledge = pbFacingTerrainTag(dir).ledge
    ledge_assist_move_generic(dir, turn_enabled)
    dx = (dir == 4 ? -2 : dir == 6 ? 2 : 0)
    dy = (dir == 8 ? -2 : dir == 2 ? 2 : 0)
    LedgeAssist.start_assist(x, y, dir) if facing_ledge &&
      @x == x + dx && @y == y + dy
  end

  alias ledge_assist_moveto moveto
  def moveto(x, y)
    LedgeAssist.end_assist if LedgeAssist.active?
    ledge_assist_moveto(x, y)
  end

  alias ledge_assist_update update
  def update
    ledge_assist_update
    LedgeAssist.update
  end
end

class Scene_Map
  alias ledge_assist_dispose dispose
  def dispose
    LedgeAssist.end_assist if LedgeAssist.active?
    ledge_assist_dispose
  end
end

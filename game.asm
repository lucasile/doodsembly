#Display Macros

.eqv DISPLAY_ADDR 0x10008000

.eqv UNIT_SIZE 4

.eqv ROW_END 256
.eqv COL_END 256

.eqv ROW_SIZE 64
.eqv COL_SIZE 64

.eqv LAST_PIXEL 16384
 
# Input

.eqv MMIO_ADDR 0xffff0000

# Colours

.eqv BACKGROUND_COLOR 0x0092bbfc

.eqv TOAST_BORDER 0x00f7a545
.eqv TOAST_BLACK 0x00000000
.eqv TOAST_WHITE 0x00ffffff
.eqv TOAST_INSIDE 0x00fadcb2
.eqv TOAST_BLUSH 0x00ff2676

# Inputs

.eqv w 119
.eqv a 97
.eqv s 115
.eqv d 100
.eqv p 112

# Timing

.eqv SLEEP 30 # sleep time in milliseconds between each frame
.eqv CHANGE_GRAVITY_FRAME_INTERVAL 4

# Player

.eqv PLAYER_TILE_OFFSET_START -652
.eqv PLAYER_TILE_OFFSET_END 8

.eqv PLAYER_WIDTH 24
.eqv PLAYER_HEIGHT 24
.eqv PLAYER_HEIGHT_ROW_OFFSET 1536

.eqv STARTING_PIXEL 15488
.eqv STARTING_LAST_POS_PIXEL 0
.eqv STARTING_Y_VELOCITY 0

.eqv GRAVITATIONAL_ACCEL 1 # acceleration unit / millisecond^2

.eqv BOTTOM_BOUNCE_FACTOR 3

.eqv INPUT_MOVE_FACTOR 1

# Collisions

.eqv BOTTOM_COLLIDER_PX_START 16128
.eqv TOP_COLLIDER_PX_START 256

# Entities
.eqv NUM_PLATFORMS_ON_SCREEN 4
.eqv PLATFORM_ARR_LENGTH 8 # 4 * 2 (platform identifier,position)
.eqv NO_PLATFORM -1 # identifier for array elements in platform that says !!! DO NOT DRAW

.eqv COINS_ARR_LENGTH 5
.eqv NO_COIN -1

.eqv COIN_WIDTH 28
.eqv COIN_HEIGHT 28
.eqv COIN_HEIGHT_ROW_OFFSET 1792

.eqv COIN_FINAL_SPAWN_BOUND 13824

.eqv PLATFORM_ROW_1 13568
.eqv PLATFORM_ROW_2 8960 
.eqv PLATFORM_ROW_3 3328 

.eqv NUM_PLATFORM_TYPES 4

.eqv STANDARD_PLATFORM_WIDTH 28
.eqv STANDARD_PLATFORM_COLOUR 0x00000000
.eqv STANDARD_BOUNCE_FACTOR 4

.eqv BREAKABLE_PLATFORM_WIDTH 36
.eqv BREAKABLE_PLATFORM_COLOUR 0x000000ff
.eqv BREAKABLE_BOUNCE_FACTOR 4

.eqv HORIZONTAL_MOVING_RIGHT_PLATFORM_WIDTH 40
.eqv HORIZONTAL_MOVING_RIGHT_PLATFORM_COLOUR 0x00000000
.eqv HORIZONTAL_MOVING_RIGHT_BOUNCE_FACTOR 3
.eqv HORIZONTAL_MOVING_RIGHT_SPEED 4

.eqv HORIZONTAL_MOVING_LEFT_PLATFORM_WIDTH 40
.eqv HORIZONTAL_MOVING_LEFT_PLATFORM_COLOUR 0x00000000
.eqv HORIZONTAL_MOVING_LEFT_BOUNCE_FACTOR 4
.eqv HORIZONTAL_MOVING_LEFT_SPEED 4

.eqv WING_WIDTH 52
.eqv WING_HEIGHT 40
.eqv WING_HEIGHT_ROW_OFFSET 2560
.eqv WING_EQUIP_VELOCITY_Y 2
.eqv WING_FRAME_LIFETIME 20

.eqv WING_ROW_POSITION 9984
.eqv WING_CHANCE 2 # 20%

.eqv CLOCK_HEIGHT 28
.eqv CLOCK_WIDTH 28
.eqv CLOCK_HEIGHT_ROW_OFFSET 1792
.eqv CLOCK_FRAME_LIFETIME 80

.eqv CLOCK_ROW_POSITION 256
.eqv CLOCK_CHANCE 4 # 40%

.eqv HEART_HEIGHT 24
.eqv HEART_WIDTH 28
.eqv HEART_HEIGHT_ROW_OFFSET 1536
.eqv HEART_FRAME_LIFETIME 20

.eqv HEART_ROW_POSITION 6656
.eqv HEART_CHANCE 1 # 10%

# UI

.eqv DOLLAR_SIGN_WIDTH 28
.eqv DOLLAR_SIGN_HEIGHT 36
.eqv DOLLAR_SIGN_END_OFFSET 2332

.eqv NUM_WIDTH 12
.eqv NUM_HEIGHT 20
.eqv NUM_END_OFFSET 1292

.data
	platforms: .word NO_PLATFORM:PLATFORM_ARR_LENGTH # -1:8
	num_platforms: .word 0
	
	coins: .word NO_COIN:COINS_ARR_LENGTH
	num_coins_on_screen: .word 0
	coins_collected: .word 0
	
	wing: .word 0:4 # wing[0] = 1 iff exists for this screen, wing[1] = position for this screen # wing[2] = 1 iff player has wing , wing[3] = counter
	clock: .word 0:4 # same as wing
	heart: .word 0:3 # same as wing but without frame counter
	heart_safe_frames: .word 0

.text

.globl main

main:

	li $s0, DISPLAY_ADDR # store display address to $s0, long-lived values
	li $s1, -1 # LAST PRESSED KEY
	li $s3, STARTING_PIXEL # player position
	li $s4, STARTING_LAST_POS_PIXEL # store last player position_x after move
	li $s5, STARTING_LAST_POS_PIXEL # store last player position_y after move
	li $s6, STARTING_Y_VELOCITY # store player's vertical velocity in unit / millisecond
	li $s7, 0 # FRAME COUNTER
	
	
	# start player out with heart so he can bounce off the bottom 
	li $t0, 1
	sw $t0, heart + 8
	
	jal create_screen
	
	jal refresh_screen # color the background
	
	li $a0, 1000
	li $v0, 32
	syscall
	
	j game_loop # start the game loop
	
	j end
	
	
restart_game:
 
	sw $zero, coins_collected # reset coins collected
	jal clear_screen
	j main
	

game_loop:

	addi $s7, $s7, 1

	jal limit_frames # sleep for SLEEP macro time

	jal draw_screen

	jal get_pressed_key # loads the last pressed key in $s1
	
	# jal shift_player_up # shift player up like on trampoline
	
	jal calculate_gravity_velocity
	
	jal apply_gravity
	
	jal input_handler # uses the key in $s1
	
	jal update_heart_frames
	jal collider_handler
	
	beq $s7, CHANGE_GRAVITY_FRAME_INTERVAL, reset_frame_counter
	
	# Tell the display to update. *** ONLY FOR EMARS ***
	# li   $t8, DISPLAY_ADDR
	# li   $t9, 1
	# sb   $t9, 0($t8)
	
	j game_loop
	
	
draw_screen:

	addi $sp, $sp, -4
	sw $ra, 0($sp)

	li $a1, BACKGROUND_COLOR # store the color we replace the last position of the player with here
	jal draw_player # draw the player based on position in $s3
	jal draw_and_init_colliding_platforms
	jal draw_and_init_wing_collider
	jal draw_and_init_clock_collider
	jal draw_and_init_heart_collider
	jal draw_and_init_coin_collider
	
	li $a0, 0x00000000
	li $a1, DISPLAY_ADDR
	addi $a1, $a1, ROW_END
	addi $a1, $a1, 4
	li $a2, BACKGROUND_COLOR
	jal draw_coin_counter
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
create_screen:
	
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $v0, 42
	li $a1, COINS_ARR_LENGTH
	syscall # random num from 0 to 5
	
	jal spawn_coins
	
	jal spawn_platforms
	
	jal spawn_powerups
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	
clear_screen:

	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal clear_coins
	
	jal clear_powerups
	
	jal clear_platforms
	
	jal refresh_screen
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4

	jr $ra
	

clear_coins:
	
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $t0, 0 # counter
	
	clear_coins_loop:
	
		bge $t0, COINS_ARR_LENGTH, cancel_clear_coins
		
		addi $sp, $sp, -4
		sw $t0, 0($sp)
		
		move $a0, $t0
		jal destroy_coin
		
		lw $t0, 0($sp)
		addi $sp, $sp, 4
		
		addi $t0, $t0, 1 # increment counter
		
		j clear_coins_loop
		
	cancel_clear_coins:
	
		lw $ra, 0($sp)
		addi $sp, $sp, 4
	
		jr $ra
	


clear_powerups:

	sw $zero, wing
	sw $zero, wing + 4
	sw $zero, clock
	sw $zero, clock + 4
	sw $zero, heart
	sw $zero, heart + 4
	
	jr $ra


clear_platforms:
	
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $t0, 0 # counter
	
	clear_platforms_loop:
	
		bge $t0, NUM_PLATFORMS_ON_SCREEN, cancel_clear_platforms
		
		addi $sp, $sp, -4
		sw $t0, 0($sp)
		
		move $a0, $t0
		jal destroy_platform
		
		lw $t0, 0($sp)
		addi $sp, $sp, 4
		
		addi $t0, $t0, 1 # increment counter
		
		j clear_platforms_loop
		
	cancel_clear_platforms:
	
		lw $ra, 0($sp)
		addi $sp, $sp, 4
	
		jr $ra
	
	
spawn_powerups:

	li $v0, 42
	li $a1, 9
	syscall
	
	addi $a0, $a0, 1
	
	ble $a0, WING_CHANCE, spawn_wing
	
	j try_spawn_clock_heart
	
	spawn_wing:
	
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		li $a0, ROW_END
		li $a1, WING_WIDTH
		jal create_random_position
		
		addi $a0, $v0, WING_ROW_POSITION
		
		jal create_wing
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
		j try_spawn_clock_heart
		
	spawn_clock:

		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		li $a0, ROW_END
		li $a1, CLOCK_WIDTH
		jal create_random_position
		
		addi $a0, $v0, CLOCK_ROW_POSITION
		
		jal create_clock
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4

		j try_spawn_heart
		
	spawn_heart:
	
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		li $a0, ROW_END
		li $a1, HEART_WIDTH
		jal create_random_position
		
		addi $a0, $v0, HEART_ROW_POSITION
		
		jal create_heart
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
	
		jr $ra
	
	try_spawn_clock_heart:
	
		li $v0, 42
		li $a1, 9
		syscall
	
		addi $a0, $a0, 1
	
		ble $a0, CLOCK_CHANCE, spawn_clock
		
		j try_spawn_heart
	
	
	try_spawn_heart:
	
		li $v0, 42
		li $a1, 9
		syscall
	
		addi $a0, $a0, 1
	
		ble $a0, HEART_CHANCE, spawn_heart
		
		jr $ra
	
	
spawn_platforms:

	addi $sp, $sp, -4
	sw $ra, 0($sp)

	li $a2, PLATFORM_ROW_1
	jal create_random_platform
	
	li $a2, PLATFORM_ROW_2
	jal create_random_platform
	
	li $a2, PLATFORM_ROW_3
	jal create_random_platform
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
	# $a2 = ROW PX START
	create_random_platform:

		addi $sp, $sp, -4
		sw $ra, 0($sp)

		jal random_platform_id
	
		addi $sp, $sp, -4
		sw $v0, 0($sp) # save id
	
		move $a0, $v0
		jal get_platform_information
	
		li $a0, ROW_END # start pixel
		move $a1, $v0 # width of platform
		jal create_random_position
	
		add $a1, $a2, $v0 # random position
	
		lw $a0, 0($sp)
		addi $sp, $sp, 4 # restore id
	
		jal create_platform
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
		jr $ra
	
	
random_platform_id:

	li $v0, 42
	li $a1, NUM_PLATFORM_TYPES
	addi $a1, $a1, -1 # correct to start at id = 1
	syscall
	
	addi $a0, $a0, 1 # correct to start at id = 1
	
	move $v0, $a0
	
	jr $ra

	

# $a0 = num coins
spawn_coins:
	
	addi $sp, $sp, -4
	sw $ra, 0($sp) # save $ra
	
	li $t0, 0 # counter
	move $t1, $a0
	
	spawn_coins_loop:
	
		bge $t0, $t1, cancel_spawn_coins
		
		addi $sp, $sp, -8
		sw $t0, 0($sp) # save $t0 and $t1
		sw $t1, 4($sp)
		
		li $a0, COIN_FINAL_SPAWN_BOUND
		li $a1, COIN_WIDTH
		jal create_random_position
		
		move $a0, $v0
		jal create_coin
		
		lw $t0, 0($sp)
		lw $t1, 4($sp)
		addi $sp, $sp, 8 # restore $t0 and $t1
		
		addi $t0, $t0, 1 # increment counter
		
		j spawn_coins_loop
	
	cancel_spawn_coins:
	
		lw $ra, 0($sp)
		addi $sp, $sp, 4
	
		jr $ra
	
	
reset_frame_counter:
	li $s7, 0
	j game_loop
	

# a0 = position address
create_wing:
	
	lw $t0, wing
	
	beq $t0, 1, cancel_create_wing
	
	li $t1, 1 # to set enable
	
	sw $t1, wing
	sw $a0, wing + 4
	sw $zero, wing + 8
	sw $zero, wing + 12
	
	jr $ra
	
	cancel_create_wing:
		jr $ra
		
		
# a0 = position address
create_clock:
	
	lw $t0, clock
	
	beq $t0, 1, cancel_create_clock
	
	li $t1, 1 # to set enable
	
	sw $t1, clock
	sw $a0, clock + 4
	sw $zero, clock + 8
	sw $zero, clock + 12
	
	jr $ra
	
	cancel_create_clock:
		jr $ra
		
		
# a0 = position address
create_heart:

	lw $t0, heart
	beq $t0, 1, cancel_create_heart
	li $t1, 1
	
	sw $t1, heart
	sw $a0, heart + 4
	sw $zero, heart + 8
	
	jr $ra
	
	cancel_create_heart:
		jr $ra
		
		
destroy_wing_item:
	
	lw $t0, wing
	
	bne $t0, 1, cancel_destroy_wing
	
	addi $sp, $sp, -4 # save $ra
	sw $ra, 0($sp)
	
	li $a0, BACKGROUND_COLOR
	lw $a1, wing + 4 # position start
	addi $a2, $a1, WING_HEIGHT_ROW_OFFSET
	addi $a2, $a2, WING_WIDTH # position end
	li $a3, WING_WIDTH
	
	jal draw_rect
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4 # restore $ra
	
	li $t1, 1
	
	sw $zero, wing
	sw $zero, wing + 4
	sw $t1, wing + 8
	
	jr $ra
	
	cancel_destroy_wing:
		jr $ra
		
		
destroy_clock_item:
	
	lw $t0, clock
	
	bne $t0, 1, cancel_destroy_clock
	
	addi $sp, $sp, -4 # save $ra
	sw $ra, 0($sp)
	
	li $a0, BACKGROUND_COLOR
	lw $a1, clock + 4 # position start
	addi $a2, $a1, CLOCK_HEIGHT_ROW_OFFSET
	addi $a2, $a2, CLOCK_WIDTH # position end
	li $a3, CLOCK_WIDTH
	
	jal draw_rect
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4 # restore $ra
	
	li $t1, 1
	
	sw $zero, clock
	sw $zero, clock + 4
	sw $t1, clock + 8
	
	jr $ra
	
	cancel_destroy_clock:
		jr $ra
	

destroy_heart_item:
	
	lw $t0, heart
	
	bne $t0, 1, cancel_destroy_heart
	
	addi $sp, $sp, -4 # save $ra
	sw $ra, 0($sp)
	
	li $a0, BACKGROUND_COLOR
	lw $a1, heart + 4 # position start
	addi $a2, $a1, HEART_HEIGHT_ROW_OFFSET
	addi $a2, $a2, HEART_WIDTH # position end
	li $a3, HEART_WIDTH
	
	jal draw_rect
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4 # restore $ra
	
	li $t1, 1
	
	sw $zero, heart
	sw $zero, heart + 4
	sw $t1, heart + 8
	
	jr $ra
	
	cancel_destroy_heart:
		jr $ra
	

# a0 = position address
create_coin:

	lw $t0, num_coins_on_screen
	
	bge $t0, COINS_ARR_LENGTH, cancel_create_coin
	
	sll $t2, $t0, 2 # x 4 bytes
	
	lw $t1, coins + 0($t2)
	
	bne $t1, -1, cancel_create_coin
	
	sw $a0, coins + 0($t2)
	
	addi $t0, $t0, 1
	
	sw $t0, num_coins_on_screen
	
	jr $ra
	
	cancel_create_coin:
		jr $ra
	
# $a0 = index of coin
destroy_coin:
	
	bge $a0, COINS_ARR_LENGTH, cancel_destroy_coin
	
	li $t0, -1 # set to nothing
	
	sll $a0, $a0, 2 # x 4 bytes
	
	lw $a1, coins + 0($a0)
	
	beq $a1, -1, cancel_destroy_coin

	sw $t0, coins + 0($a0) # set it to -1
	
	lw $t1, num_coins_on_screen
	addi $t1, $t1, -1
	
	sw $t1, num_coins_on_screen
	
	li $a0, BACKGROUND_COLOR
	addi $a2, $a1, COIN_WIDTH
	addi $a2, $a2, COIN_HEIGHT_ROW_OFFSET
	li $a3, COIN_WIDTH
	
	addi $sp, $sp, -4
	sw $ra 0($sp) # save $ra
	
	jal draw_rect
	
	lw $ra, 0($sp) # restore $ra
	addi $sp, $sp, 4
	
	jr $ra
	
	cancel_destroy_coin:
		jr $ra

	
# a0 = id, a1 = position address
create_platform:

	lw $t0, num_platforms

	bge $t0, NUM_PLATFORMS_ON_SCREEN, cancel_create_platform # make sure we don't exceed our array
	
	move $t2, $t0
	
	sll $t0, $t0, 3 # multiply by 2 elements per platform * 4 bytes per element = 8
	
	# store our platform info
	sw $a0, platforms + 0($t0) 
	sw $a1, platforms + 4($t0)
	
	addi $t2, $t2, 1
	
	sw $t2, num_platforms # increment num_platforms
	
	jr $ra
			
	cancel_create_platform:
		jr $ra
		
	
# $a0 = index of platform, eg) 0, 1, 2, 3 	
destroy_platform:
	
	bge $a0, NUM_PLATFORMS_ON_SCREEN, cancel_destroy_platform # make sure we only delete in our array
	
	sll $t2, $a0, 3 # get the actual start index in our array for this element
	
	lw $t5, platforms + 0($t2) # id
	
	beq $t5, -1, cancel_destroy_platform
	
	addi $sp, $sp, -4
	sw $ra, 0($sp) # save $ra
	
	lw $t6, platforms + 4($t2) # position
	
	move $a0, $t5
	
	jal get_platform_information # get width of platform
	
	move $a3, $v0 # width
	li $a0, BACKGROUND_COLOR # colour
		
	move $a1, $t6 # start address
	add $a2, $t6, $a3 # end address
	
	# push $t2 to stack to save
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	
	# draw to replace the platform
	jal draw_rect
	
	# restore $t2
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	
	li $t3, -1 # what to set to destroy
	
	# delete platform
	sw $t3, platforms + 0($t2)
	sw $t3, platforms + 4($t2)
	
	lw $t3, num_platforms
	addi $t3, $t3, -1
	sw $t3, num_platforms # decrement num platforms
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4 # restore $ra
	
	jr $ra
	
	cancel_destroy_platform:
		jr $ra
	

draw_and_init_coin_collider:

	li $t0, 0 # counter
	
	draw_coin_loop:
		
		bge $t0, COINS_ARR_LENGTH, end_coin_loop
		
		addi $sp, $sp, -8 # save $t0, $t1 to stack
		sw $t0, 0($sp)
		sw $t1, 4($sp)
		
		addi $sp, $sp, -4 # save $ra
		sw $ra, 0($sp)
		
		sll $t2, $t0, 2 # x 4 bytes
		
		lw $a0, coins + 0($t2) # $a0 = position of coin
		
		beq $a0, -1, next_iteration_coin # make sure we have a valid coin
		
		jal draw_coin
		
		# handle collisions
		
		subi $t3, $a0, DISPLAY_ADDR # absolute $t3 position, top left
        
        	addi $t4, $t3, COIN_HEIGHT_ROW_OFFSET # $t4 is bottom left
        
        	addi $t5, $s3, -PLAYER_HEIGHT_ROW_OFFSET
        	addi $t5, $t5, -12 # $t5 is top left of player
        
        	addi $t6, $s3, -12 # $t6 is bottom left of player
        
        
        	blt $t6, $t3, next_iteration_coin # bottom left player < top left coin
        	bgt $t5, $t4, next_iteration_coin # top left player > bottom left coin
        	
        
        	rem $t7, $s3, ROW_END # $t7 is row position of player top left
        
        	addi $t8, $t7, PLAYER_WIDTH # $t8 is row position of player top right
        
        	rem $t9, $t3, ROW_END # $t9 is row position of coin top left
        	
        	addi $t2, $t9, COIN_WIDTH # $t2 is row position of coin top right
  
        
        	bgt $t7, $t2, next_iteration_coin # top left row player > top right row coin
        	blt $t8, $t9, next_iteration_coin # top right row player < top left row coin
        	
        	# collision!
        	
        	lw $ra, 0($sp) # restore $ra
		addi $sp, $sp, 4

		lw $t0, 0($sp) # restore $t0, $t1 from stack
		lw $t1, 4($sp)
		addi $sp, $sp, 8
		
		addi $sp, $sp, -4
		sw $ra, 0($sp) # save $ra again
		
		move $a0, $t0
        	jal destroy_coin
        	
        	lw $ra, 0($sp)
        	addi $sp, $sp, 4 # restore $ra again
		
		lw $t7, coins_collected
		addi $t7, $t7, 1
		
		sw $t7, coins_collected # increment coins_collected
		
		addi $t0, $t0, 1
		
		j draw_coin_loop
		
	next_iteration_coin:
	
		lw $ra, 0($sp) # restore $ra
		addi $sp, $sp, 4
		
		lw $t0, 0($sp) # restore $t0, $t1 from stack
		lw $t1, 4($sp)
		addi $sp, $sp, 8
		
		addi $t0, $t0, 1
		
		j draw_coin_loop
	
	end_coin_loop:
	
		jr $ra

# we do collision in here for efficiency. if it wasn't assembly in MARS, i would separate it
draw_and_init_colliding_platforms:

	li $t0, 0 # counter
	li $t1, NUM_PLATFORMS_ON_SCREEN
	
	draw_platform_loop:
	
		bge $t0, $t1, end_platform_loop
		
		# save $t0 and $t1 to stack
		addi $sp, $sp, -8
		sw $t0, 0($sp)
		sw $t1, 4($sp)
		
		addi $sp, $sp, -4
		sw $ra, 0($sp) # save $ra
		
		mul $t2, $t0, 8 # where to access array
		
		lw $t3, platforms + 0($t2) # identifier

		beq $t3, NO_PLATFORM, next_iteration_platform # don't draw invalid platforms
		
		lw $t4, platforms + 4($t2) # position
		
		
		move $a0, $t3
		jal get_platform_information # get width and colour of platform
		
		# move moving platforms, takes $a0 = id, $a1 = num
		move $a1, $t0
		jal move_platforms
		
		
		move $a3, $v0 # width
		move $a0, $v1 # colour
		
		move $a1, $t4 # start address
		add $a2, $t4, $a3 # end address
		
		jal draw_rect
		
		# handle collisions
		add $t6, $s3, $s6 # $t0 is where player will end up with current velocity y next frame
		add $t6, $t6, $s0 # add display address 
	
		blt $t6, $a1, next_iteration_platform # if the player's next position does not pass the platform we definitely have not collided
		
		sub $t7, $s3, $s4 # pos - last_pos_x
		add $t7, $s3, $t7 # where player will likely end up x position

		rem $t7, $t7, ROW_END # get position in row
		
		sub $t8, $a1, $s0 # subtract display address to get absolute position
		rem $t8, $t8, ROW_END # get row position
		
		blt $t7, $t8, next_iteration_platform
		
		add $t9, $t8, $a3 # get end row position
		
		bgt $t7, $t9, next_iteration_platform
		
		move $a0, $t3
		move $a1, $t0
		j collide_with_platform
	
	# $a0 = id, $a1 = platform num
	move_platforms:
		
		beq $a0, 3, move_platform_right
		beq $a0, 4, move_platform_left
		
		jr $ra
		
		move_platform_right:
		
			sll $a1, $a1, 3 # x 8
			addi $a1, $a1, 4
			
			lw $t7, platforms + 0($a1)
			
			addi $t9, $t7, HORIZONTAL_MOVING_RIGHT_PLATFORM_WIDTH
			rem $t9, $t9, ROW_END
			
			li $t6, HORIZONTAL_MOVING_RIGHT_SPEED
			sll $t6, $t6, 1 # x 2
			
			li $t5, ROW_END
			sub $t5, $t5, $t6 
			
			bge $t9, $t5, make_platform_left # if they reach the edge of screen with some padding make it move left
			
			addi $sp, $sp, -4
			sw $ra, 0($sp) # save $ra
			
			move $t8, $t7 # save old position
			
			# change position
			addi $t7, $t7, HORIZONTAL_MOVING_RIGHT_SPEED
			sw $t7, platforms + 0($a1)
			
			# overwrite old platform
			li $a0, BACKGROUND_COLOR
			addi $a1, $t8, -HORIZONTAL_MOVING_RIGHT_SPEED
			addi $a2, $t8, HORIZONTAL_MOVING_RIGHT_SPEED
			li $a3, HORIZONTAL_MOVING_RIGHT_SPEED
			
			jal draw_rect
			
			lw $ra, 0($sp)
			addi $sp, $sp, 4 # restore $ra
			
			jr $ra
			
		move_platform_left:
		
			sll $a1, $a1, 3 # x 8
			addi $a1, $a1, 4
			
			lw $t7, platforms + 0($a1)
			
			rem $t9, $t7, ROW_END
			
			li $t6, HORIZONTAL_MOVING_LEFT_SPEED
			sll $t6, $t6, 1 # x 2
			
			ble $t9, $t6, make_platform_right # if they reach the edge of screen with some padding make it move left
			
			addi $sp, $sp, -4
			sw $ra, 0($sp) # save $ra
			
			move $t8, $t7 # save old position
			
			# change position
			addi $t7, $t7, -HORIZONTAL_MOVING_LEFT_SPEED
			sw $t7, platforms + 0($a1)
			
			# overwrite old platform
			li $a0, BACKGROUND_COLOR
			addi $a1, $t8, HORIZONTAL_MOVING_LEFT_PLATFORM_WIDTH
			addi $a2, $a1, HORIZONTAL_MOVING_LEFT_SPEED
			li $a3, HORIZONTAL_MOVING_LEFT_SPEED
			
			jal draw_rect
			
			lw $ra, 0($sp)
			addi $sp, $sp, 4 # restore $ra
			
			jr $ra
			
		# $a1 = offset for platform in array
		make_platform_left:
		
			li $t7, 4 # id for left moving
			
			addi $a1, $a1, -4
			sw $t7, platforms + 0($a1)
		
			jr $ra
			
		make_platform_right:
		
			li $t7, 3
			
			addi $a1, $a1, -4
			sw $t7, platforms + 0($a1)
			
			jr $ra
		
		
		
	# $a0 = id, $a1 = platform num, eg) 0, 1, 2, 3
	collide_with_platform:
		
		beq $a0, 1, collide_standard
		beq $a0, 2, collide_breakable
		beq $a0, 3, collide_horizontal_moving_right
		beq $a0, 4, collide_horizontal_moving_left
		
		j next_iteration_platform
		
		collide_standard:
			
			li $s6, -STANDARD_BOUNCE_FACTOR
			j next_iteration_platform
			
		collide_breakable:
		
			li $s6, -BREAKABLE_BOUNCE_FACTOR
			
			move $a0, $a1
			
			#jal destroy_platform
			
			j next_iteration_platform
			
		collide_horizontal_moving_right:
			
			li $s6, -HORIZONTAL_MOVING_RIGHT_BOUNCE_FACTOR
			j next_iteration_platform
			
		collide_horizontal_moving_left:
			
			li $s6, -HORIZONTAL_MOVING_LEFT_BOUNCE_FACTOR
			j next_iteration_platform
			
		
	
	next_iteration_platform:
	
		lw $ra, 0($sp) # restore $ra
		addi $sp, $sp, 4
	
		# restore $t0 and $t1
		lw $t0, 0($sp)
		lw $t1, 4($sp)
		addi $sp, $sp, 8
		
		addi $t0, $t0, 1 # increment counter
		j draw_platform_loop
		
		
	end_platform_loop:
		jr $ra
	

# $a0 = id, $v0 = width, $v1 = colour, 
get_platform_information:
	
	beq $a0, 1, standard_platform # id = 1, standard_platform
	beq $a0, 2, breakable_platform # id = 2, breakable_platform
	beq $a0, 3, horizontal_moving_right_platform # id = 3, moving horizontal platform
	beq $a0, 4, horizontal_moving_left_platform # id = 4, moving horizontal platform
	
	jr $ra
	
	breakable_platform:
		
		li $v0, BREAKABLE_PLATFORM_WIDTH
		li $v1, BREAKABLE_PLATFORM_COLOUR
		
		jr $ra
	
	standard_platform:
		
		li $v0, STANDARD_PLATFORM_WIDTH
		li $v1, STANDARD_PLATFORM_COLOUR
		
		jr $ra
		
	horizontal_moving_right_platform:
	
		li $v0, HORIZONTAL_MOVING_RIGHT_PLATFORM_WIDTH
		li $v1, HORIZONTAL_MOVING_RIGHT_PLATFORM_COLOUR
		
		jr $ra
		
	horizontal_moving_left_platform:
	
		li $v0, HORIZONTAL_MOVING_LEFT_PLATFORM_WIDTH
		li $v1, HORIZONTAL_MOVING_LEFT_PLATFORM_COLOUR
		
		jr $ra

	
update_heart_frames:

	lw $t0, heart_safe_frames
	
	beqz $t0, cancel_update_heart_frames
	
	bge $t0, HEART_FRAME_LIFETIME, reset_heart_frames
	
	addi $t0, $t0, 1
	sw $t0, heart_safe_frames
	
	jr $ra
	
	reset_heart_frames:
		sw $zero, heart_safe_frames
		jr $ra 
	
	cancel_update_heart_frames:
		jr $ra 


collider_handler:

	add $t0, $s3, $s6 # $t0 is where player will end up with current velocity next frame
	bge $t0, BOTTOM_COLLIDER_PX_START, collide_bottom
	ble $t0, TOP_COLLIDER_PX_START, collide_top

	jr $ra
	
	collide_bottom:
	
		lw $t0, heart + 8
		
		beq $t0, 1, save_player # if they have heart power-up
		
		lw $t1, heart_safe_frames
		
		bnez $t1, cancel_collision # we use heart invul frames just to make sure if player overshoots velocity for death it doesn't still die after having heart
	
		jal draw_lose_screen
		
		j end
		
	collide_top:
		
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		jal clear_screen
		
		li $t0, 1
		sw $t0, heart_safe_frames # give invulnerability frames
		
		addi $s3, $s3, STARTING_PIXEL # move player to bottom
		
		jal create_screen
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
		jr $ra
		
		
	save_player:
	
		li $t0, 0
		sw $t0, heart + 8

		li $t0, 1
		sw $t0, heart_safe_frames
	
		li $a2, -4
		move $s6, $a2 # bounce
		
		jr $ra
		
	cancel_collision:
		jr $ra


game_loop_finish:
	j end
	
apply_gravity:
	move $a1, $s6
	j shift_player_down
	
	
calculate_gravity_velocity:

	lw $t0, wing + 8
	
	beq $t0, 1, set_wing_velocity
	
	lw $t1, clock + 8
	
	beq $t1, 1, set_clock_velocity

	beq $s7, CHANGE_GRAVITY_FRAME_INTERVAL, calculate_gravity
	jr $ra
	
	calculate_gravity:
		move $t0, $s6 # save V_0 into $t0 
		addi $s6, $t0, GRAVITATIONAL_ACCEL
		jr $ra
		
	set_clock_velocity:
		
		li $s6, 0
		
		lw $t0, clock + 12
		
		bge $t0, CLOCK_FRAME_LIFETIME, remove_clock_effect
		
		addi $t0, $t0, 1
		sw $t0, clock + 12
		
		jr $ra
		
	set_wing_velocity:
	
		li $s6, -WING_EQUIP_VELOCITY_Y
		
		lw $t0, wing + 12 # frame counter
		
		bge $t0, WING_FRAME_LIFETIME, remove_wing_effect
		
		addi $t0, $t0, 1
		sw $t0, wing + 12 # increment frame counter
		
		jr $ra
		
	remove_clock_effect:
	
		sw $zero, clock + 8
		sw $zero, clock + 12
		
		jr $ra
		
	remove_wing_effect:
	
		li $s6, 0 # cancel the upward velocity
		sw $zero, wing + 8 # remove from player
		sw $zero, wing + 12 # reset counter
		
		jr $ra
	
	

# $s1 is the key arg
input_handler:
	li $a1, INPUT_MOVE_FACTOR
	beq $s1, a, shift_player_left
	beq $s1, d, shift_player_right
	beq $s1, p, restart_game
	jr $ra

# $a1 = unit multiplier int for shifting

# shift player up by going up a row
shift_player_up:
	move $s5, $s3
	mul $t1, $a1, -ROW_END
	add $s3, $s3, $t1
	jr $ra
	
# shift player down by going down a row
shift_player_down:
	move $s5, $s3
	mul $t1, $a1, ROW_END
	add $s3, $s3, $t1
	jr $ra
	
# shift player left by going left a unit
shift_player_left:
	move $s4, $s3
	mul $t1, $a1, -UNIT_SIZE
	add $s3, $s3, $t1
	jr $ra

# shift player right by going right a unit
shift_player_right:
	move $s4, $s3
	mul $t1, $a1, UNIT_SIZE
	add $s3, $s3, $t1
	jr $ra


# stores pressed key in $s1
get_pressed_key:

	li $t1, MMIO_ADDR

	lw $t0, 0($t1) # load into $t0
	beq $t0, 1, key_pressed # check if the key was pressed, if so go to key_pressed
	jr $ra # jump back to the loop
	
	key_pressed:
		lw $s1, 4($t1) # load the pressed key into $v1 as the return register
		jr $ra # jump back to loop


refresh_screen:
	
	addi $t0, $s0, LAST_PIXEL # put address of last pixel into $t0
	move $t1, $s0 # cell counter
	li $t2, BACKGROUND_COLOR # color
	
	refresh_screen_loop:
		bge $t1, $t0, refresh_finish # cell counter > last pixel address -> goto refresh_finish
		sw $t2, 0($t1) # color pixel at cell counter address
		addi $t1, $t1, UNIT_SIZE # increment cell counter
		j refresh_screen_loop # loop
		
	refresh_finish:
		jr $ra # jump back to where we were


# a0 = upper bound, a1 = right padding (eg, wing width), returns position with display addr at $v0
create_random_position:

	move $t0, $a0 # save $a0
	move $t1, $a1 # save $a1

	li $v0, 42
	li $a1, ROW_END
	sub $a1, $a1, $t1
	syscall

	rem $t2, $a0, 4 # get remainder of random number
	sub $a0, $a0, $t2 # correct for word alignment with remainder
	
	move $t3, $a0 # save row position in $t3
	
	srl $t0, $t0, 8 # 256 = 2^8, to divide by 256 we shift right 8 times
	move $a1, $t0
	syscall
	
	rem $t2, $a0, 4
	sub $a0, $a0, $t2 # correct word alignment
	
	sll $a0, $a0, 8 # multiply by 256 again by shifting left 8 times, it seems convoluted to do this but it saves annoying edge bugs and this won't be run very often
	
	add $v0, $t3, $a0 # add x and y offsets
	addi $v0, $v0, DISPLAY_ADDR # add display address
		
	jr $ra


# sleeps for the specified SLEEP macro 
limit_frames:

	li $a0, SLEEP
	li $v0, 32
	syscall
	jr $ra


end:
	li $v0, 10
	syscall

	

# $a0 = colour, $a1 = position, $a2 = background color
draw_coin_counter:

	move $t0, $a1
	
	move $t7, $a0
	
	# refresh part of screen first 
	
	lw $t1, coins_collected
	
	move $a0, $a2
	move $a1, $t0
	
	bge $t1, 10, draw_$
	
	# refresh for standard number
	addi $a2, $a1, NUM_END_OFFSET
	li $a3, NUM_WIDTH
	
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal draw_rect
	
	lw $t1, coins_collected # we need to reload it since it was overwritten by draw_rect
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	beq $t1, 0, draw_0
	beq $t1, 1, draw_1
	beq $t1, 2, draw_2
	beq $t1, 3, draw_3
	beq $t1, 4, draw_4
	beq $t1, 5, draw_5
	beq $t1, 6, draw_6
	beq $t1, 7, draw_7
	beq $t1, 8, draw_8
	beq $t1, 9, draw_9
	
	jr $ra
	
	draw_$:
	
		# refresh specifically for size of $
		addi $a2, $a1, DOLLAR_SIGN_END_OFFSET
		li $a3, DOLLAR_SIGN_WIDTH
		
		addi $sp, $sp, -4 # save $ra
		sw $ra, 0($sp)
		
		jal draw_rect
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
		li $t1, 0x004caf50
        	li $t2, 0x0000704
        	sw $t2, 12($t0)
        	sw $t1, 264($t0)
        	sw $t2, 268($t0)
        	sw $t1, 272($t0)
        	sw $t1, 516($t0)
        	sw $t2, 524($t0)
        	sw $t1, 532($t0)
        	sw $t1, 772($t0)
        	sw $t2, 780($t0)
        	sw $t1, 1032($t0)
        	sw $t2, 1036($t0)
        	sw $t1, 1040($t0)
        	sw $t2, 1292($t0)
        	sw $t1, 1300($t0)
        	sw $t1, 1540($t0)
        	sw $t2,	1548($t0)
        	sw $t1, 1556($t0)
        	sw $t1, 1800($t0)
        	sw $t2, 1804($t0)
        	sw $t1, 1808($t0)
        	sw $t2, 2060($t0)
		
		jr $ra 
	
	draw_0:
		move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 256($t0)
        	sw $t1, 264($t0)
        	sw $t1, 512($t0)
        	sw $t1, 520($t0)
        	sw $t1, 768($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1024($t0)
        	sw $t1, 1028($t0)
        	sw $t1, 1032($t0)
        	
		jr $ra
	
	draw_1:
		move $t1, $t7
        	sw $t1, 4($t0)
        	sw $t1, 256($t0)
        	sw $t1, 260($t0)
        	sw $t1, 516($t0)
        	sw $t1, 772($t0)
        	sw $t1, 1024($t0)
        	sw $t1, 1028($t0)
        	sw $t1, 1032($t0)
	
		jr $ra
	
	draw_2:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 264($t0)
        	sw $t1, 512($t0)
        	sw $t1, 516($t0)
        	sw $t1, 520($t0)
        	sw $t1, 768($t0)
        	sw $t1, 1024($t0)
        	sw $t1, 1028($t0)
        	sw $t1, 1032($t0)
        	
		jr $ra 
	
	draw_3:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 264($t0)
        	sw $t1, 512($t0)
        	sw $t1, 516($t0)
        	sw $t1, 520($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1024($t0)
        	sw $t1, 1028($t0)
        	sw $t1, 1032($t0)

		jr $ra
	
	draw_4:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 8($t0)
        	sw $t1, 256($t0)
        	sw $t1, 264($t0)
        	sw $t1, 512($t0)
        	sw $t1, 516($t0)
        	sw $t1, 520($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1032($t0)

		jr $ra
	
	draw_5:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 256($t0)
        	sw $t1, 512($t0)
        	sw $t1, 516($t0)
        	sw $t1, 520($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1024($t0)
        	sw $t1, 1028($t0)
        	sw $t1, 1032($t0)

		jr $ra
	
	draw_6:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 256($t0)
        	sw $t1, 512($t0)
        	sw $t1, 516($t0)
        	sw $t1, 520($t0)
        	sw $t1, 768($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1024($t0)
        	sw $t1, 1028($t0)
        	sw $t1, 1032($t0)

		jr $ra
	
	draw_7:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 264($t0)
        	sw $t1, 520($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1032($t0)

		jr $ra
	
	draw_8:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 256($t0)
        	sw $t1, 264($t0)
        	sw $t1, 512($t0)
        	sw $t1, 516($t0)
        	sw $t1, 520($t0)
        	sw $t1, 768($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1024($t0)
        	sw $t1, 1028($t0)
        	sw $t1, 1032($t0)

		jr $ra
	
	draw_9:
	        move $t1, $t7
        	sw $t1, 0($t0)
        	sw $t1, 4($t0)
        	sw $t1, 8($t0)
        	sw $t1, 256($t0)
        	sw $t1, 264($t0)
        	sw $t1, 512($t0)
        	sw $t1, 516($t0)
        	sw $t1, 520($t0)
        	sw $t1, 776($t0)
        	sw $t1, 1032($t0)

		jr $ra

# $a0 = start address
draw_coin:
	
	move $t0, $a0

	li $t1, 0x00ffb700
        li $t2, 0x00fc972a
        li $t3, 0x00ffc83d
        li $t4, 0x00000000
        sw $t4, 8($t0)
        sw $t4, 12($t0)
        sw $t4, 16($t0)
        sw $t4, 260($t0)
        sw $t1, 264($t0)
        sw $t3, 268($t0)
        sw $t3, 272($t0)
        sw $t4, 276($t0)
        sw $t4, 512($t0)
        sw $t1, 516($t0)
        sw $t1, 520($t0)
        sw $t2, 524($t0)
        sw $t1, 528($t0)
        sw $t3, 532($t0)
        sw $t4, 536($t0)
        sw $t4, 768($t0)
        sw $t1, 772($t0)
        sw $t2, 776($t0)
        sw $t1, 780($t0)
        sw $t3, 784($t0)
        sw $t1, 788($t0)
        sw $t4, 792($t0)
        sw $t4, 1024($t0)
        sw $t1, 1028($t0)
        sw $t3, 1032($t0)
        sw $t3, 1036($t0)
        sw $t1, 1040($t0)
        sw $t1, 1044($t0)
        sw $t4, 1048($t0)
        sw $t4, 1284($t0)
        sw $t1, 1288($t0)
        sw $t1, 1292($t0)
        sw $t1, 1296($t0)
        sw $t4, 1300($t0)
        sw $t4, 1544($t0)
        sw $t4, 1548($t0)
        sw $t4, 1552($t0)
        
        jr $ra

		
draw_and_init_clock_collider:

	# check if a clock exists this level 
	la $t0, clock
	lw $t1, 0($t0)
	bne $t1, 1, cancel_draw_clock
	
	lw $t0, 4($t0)
	
	# draw clock
	
	li $t1, 0x00ffffff
        li $t2, 0x0000ff9
        li $t3, 0x00ff0000
        li $t4, 0x00000000
        sw $t4, 8($t0)
        sw $t4, 12($t0)
        sw $t4, 16($t0)
        sw $t4, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 268($t0)
        sw $t1, 272($t0)
        sw $t4, 276($t0)
        sw $t4, 512($t0)
        sw $t1, 516($t0)
        sw $t1, 520($t0)
        sw $t1, 524($t0)
        sw $t3, 528($t0)
        sw $t1, 532($t0)
        sw $t4, 536($t0)
        sw $t4, 768($t0)
        sw $t2, 772($t0)
        sw $t2, 776($t0)
        sw $t4, 780($t0)
        sw $t1, 784($t0)
        sw $t1, 788($t0)
        sw $t4, 792($t0)
        sw $t4, 1024($t0)
        sw $t1, 1028($t0)
        sw $t1, 1032($t0)
        sw $t1, 1036($t0)
        sw $t1, 1040($t0)
        sw $t1, 1044($t0)
        sw $t4, 1048($t0)
        sw $t4, 1284($t0)
        sw $t1, 1288($t0)
        sw $t1, 1292($t0)
        sw $t1, 1296($t0)
        sw $t4, 1300($t0)
        sw $t4, 1544($t0)
        sw $t4, 1548($t0)
        sw $t4, 1552($t0)
        
        # clock collision
        
        subi $t0, $t0, DISPLAY_ADDR # absolute $t0 position, top left
        
        addi $t5, $t0, CLOCK_HEIGHT_ROW_OFFSET # $t5 is bottom left
        
        addi $t1, $s3, -PLAYER_HEIGHT_ROW_OFFSET
        addi $t1, $t1, -12 # $t1 is top left of player
        
        addi $t3, $s3, -12 # $t3 is bottom left of player
        
        
        blt $t3, $t0, cancel_draw_clock # bottom left player < top left clock
        bgt $t1, $t5, cancel_draw_clock # top left player > bottom left clock
        
        
        rem $t4, $t1, ROW_END # $t4 is row position of player top left
        
        addi $t5, $t4, PLAYER_WIDTH # $t5 is row position of player top right
        
        rem $t6, $t0, ROW_END # $t6 is row position of clock top left
        
        addi $t7, $t6, WING_WIDTH # $t7 is row position of clock top right
        
        
        bgt $t4, $t7, cancel_draw_clock # top left row player > top right row clock
        blt $t5, $t6, cancel_draw_clock # top right row player < top left row clock
        
        addi $sp, $sp, -4 # save $ra
        sw $ra, 0($sp)
        
        # collision!
        jal destroy_clock_item
        
        lw $ra, 0($sp) # restore $ra
        addi $sp, $sp, 4
        
        jr $ra
        
        cancel_draw_clock:
        	jr $ra
        	
        	
draw_and_init_heart_collider:

	# check if a heart exists this level 
	la $t0, heart
	lw $t1, 0($t0)
	bne $t1, 1, cancel_draw_heart
	
	lw $t0, 4($t0)
	
	# draw heart
        
        li $t1, 0x00ffffff
        li $t2, 0x00db4040
        li $t3, 0x00d50000
        li $t4, 0x00000000
        sw $t3, 4($t0)
        sw $t3, 8($t0)
        sw $t3, 16($t0)
        sw $t3, 20($t0)
        sw $t3, 256($t0)
        sw $t4, 260($t0)
        sw $t1, 264($t0)
        sw $t3, 268($t0)
        sw $t4, 272($t0)
        sw $t1, 276($t0)
        sw $t3, 280($t0)
        sw $t3, 512($t0)
        sw $t2, 516($t0)
        sw $t2, 520($t0)
        sw $t3, 524($t0)
        sw $t2, 528($t0)
        sw $t2, 532($t0)
        sw $t3, 536($t0)
        sw $t3, 772($t0)
        sw $t4, 776($t0)
        sw $t3, 780($t0)
        sw $t4, 784($t0)
        sw $t3, 788($t0)
        sw $t3, 1032($t0)
        sw $t4, 1036($t0)
        sw $t3, 1040($t0)
        sw $t3, 1292($t0)
        
        # heart collision
        
        subi $t0, $t0, DISPLAY_ADDR # absolute $t0 position, top left
        
        addi $t5, $t0, HEART_HEIGHT_ROW_OFFSET # $t5 is bottom left
        
        addi $t1, $s3, -PLAYER_HEIGHT_ROW_OFFSET
        addi $t1, $t1, -12 # $t1 is top left of player
        
        addi $t3, $s3, -12 # $t3 is bottom left of player
        
        
        blt $t3, $t0, cancel_draw_heart # bottom left player < top left heart
        bgt $t1, $t5, cancel_draw_heart # top left player > bottom left heart
        
        
        rem $t4, $t1, ROW_END # $t4 is row position of player top left
        
        addi $t5, $t4, PLAYER_WIDTH # $t5 is row position of player top right
        
        rem $t6, $t0, ROW_END # $t6 is row position of heart top left
        
        addi $t7, $t6, WING_WIDTH # $t7 is row position of heart top right
        
        
        bgt $t4, $t7, cancel_draw_heart # top left row player > top right row heart
        blt $t5, $t6, cancel_draw_heart # top right row player < top left row heart
        
        addi $sp, $sp, -4 # save $ra
        sw $ra, 0($sp)
        
        # collision!
        jal destroy_heart_item
        
        lw $ra, 0($sp) # restore $ra
        addi $sp, $sp, 4
        
        jr $ra
        
        cancel_draw_heart:
        	jr $ra


		
draw_and_init_wing_collider:

	# check if a wing exists this level 
	la $t0, wing
	lw $t1, 0($t0)
	bne $t1, 1, cancel_draw_wings
	
	lw $t0, 4($t0)

	li $t1, 0x00ffffff
        li $t2, 0x00bdbdbd
        li $t3, 0x00000000
        
        sw $t3, 4($t0)
        sw $t3, 8($t0)
        sw $t3, 40($t0)
        sw $t3, 44($t0)
        sw $t3, 256($t0)
        sw $t1, 260($t0)
        sw $t3, 264($t0)
        sw $t3, 268($t0)
        sw $t3, 292($t0)
        sw $t3, 296($t0)
        sw $t1, 300($t0)
        sw $t3, 304($t0)
        sw $t3, 512($t0)
        sw $t3, 516($t0)
        sw $t2, 520($t0)
        sw $t1, 524($t0)
        sw $t3, 528($t0)
        sw $t3, 544($t0)
        sw $t1, 548($t0)
        sw $t2, 552($t0)
        sw $t3, 556($t0)
        sw $t3, 560($t0)
        sw $t3, 768($t0)
        sw $t1, 772($t0)
        sw $t3, 776($t0)
        sw $t1, 780($t0)
        sw $t3, 784($t0)
        sw $t3, 800($t0)
        sw $t1, 804($t0)
        sw $t3, 808($t0)
        sw $t1, 812($t0)
        sw $t3, 816($t0)
        sw $t3, 1028($t0)
        sw $t2, 1032($t0)
        sw $t1, 1036($t0)
        sw $t1, 1040($t0)
        sw $t3, 1044($t0)
        sw $t3, 1052($t0)
        sw $t1, 1056($t0)
        sw $t1, 1060($t0)
        sw $t2, 1064($t0)
        sw $t3, 1068($t0)
        sw $t1, 1072($t0)
        sw $t3, 1280($t0)
        sw $t1, 1284($t0)
        sw $t3, 1288($t0)
        sw $t2, 1292($t0)
        sw $t1, 1296($t0)
        sw $t3, 1300($t0)
        sw $t3, 1308($t0)
        sw $t1, 1312($t0)
        sw $t2, 1316($t0)
        sw $t3, 1320($t0)
        sw $t1, 1324($t0)
        sw $t3, 1328($t0)
        sw $t3, 1536($t0)
        sw $t2, 1540($t0)
        sw $t1, 1544($t0)
        sw $t3, 1548($t0)
        sw $t2, 1552($t0)
        sw $t3, 1556($t0)
        sw $t3, 1564($t0)
        sw $t2, 1568($t0)
        sw $t3, 1572($t0)
        sw $t1, 1576($t0)
        sw $t2, 1580($t0)
        sw $t3, 1584($t0)
        sw $t3, 1796($t0)
        sw $t3, 1800($t0)
        sw $t1, 1804($t0)
        sw $t1, 1808($t0)
        sw $t3, 1812($t0)
        sw $t3, 1820($t0)
        sw $t1, 1824($t0)
        sw $t1, 1828($t0)
        sw $t3, 1832($t0)
        sw $t3, 1836($t0)
        sw $t3, 2056($t0)
        sw $t2, 2060($t0)
        sw $t1, 2064($t0)
        sw $t3, 2068($t0)
        sw $t3, 2076($t0)
        sw $t1, 2080($t0)
        sw $t2, 2084($t0)
        sw $t3, 2088($t0)
        sw $t3, 2316($t0)
        sw $t3, 2320($t0)
        sw $t3, 2336($t0)
        sw $t3, 2340($t0)
        
        # wing collision
        
        subi $t0, $t0, DISPLAY_ADDR # absolute $t0 position, top left
        
        addi $t5, $t0, WING_HEIGHT_ROW_OFFSET # $t5 is bottom left
        
        addi $t1, $s3, -PLAYER_HEIGHT_ROW_OFFSET
        addi $t1, $t1, -12 # $t1 is top left of player
        
        addi $t3, $s3, -12 # $t3 is bottom left of player
        
        
        blt $t3, $t0, cancel_draw_wings # bottom left player < top left wing
        bgt $t1, $t5, cancel_draw_wings # top left player > bottom left wing
        
        
        rem $t4, $t1, ROW_END # $t4 is row position of player top left
        
        addi $t5, $t4, PLAYER_WIDTH # $t5 is row position of player top right
        
        rem $t6, $t0, ROW_END # $t6 is row position of wing top left
        
        addi $t7, $t6, WING_WIDTH # $t7 is row position of wing top right
        
        
        bgt $t4, $t7, cancel_draw_wings # top left row player > top right row wing
        blt $t5, $t6, cancel_draw_wings # top right row player < top left row wing
        
        addi $sp, $sp, -4 # save $ra
        sw $ra, 0($sp)
        
        # collision!
        jal destroy_wing_item
        
        lw $ra, 0($sp) # restore $ra
        addi $sp, $sp, 4
        
        jr $ra
        
        cancel_draw_wings:
        	jr $ra


# $a1 = color to replace with
draw_player:
	
	addi $t0, $s3, DISPLAY_ADDR
	
	li $t1, TOAST_BORDER # border colour
	li $t2, TOAST_INSIDE # inside colour
	li $t3, TOAST_BLACK # eyes and mouth
	li $t4, TOAST_WHITE # eyes
	
	# draw border
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	
	# following are for new 64 x 64 screen size (units)
	sw $t1, -264($t0)
	sw $t1, -520($t0) 
	sw $t1, -776($t0)
	sw $t1, -1036($t0)
	sw $t1, -1288($t0)
	sw $t1, -1284($t0)
	sw $t1, -1280($t0)
	sw $t1, -1276($t0)
	sw $t1, -508($t0)
	
	# draw inside
	sw $t2, -260($t0)
	sw $t2, -512($t0)
	sw $t2, -768($t0)
	sw $t1, -764($t0)
	sw $t2 -1024($t0)
	
	# draw eyes
	sw $t3, -1028($t0)
	sw $t4, -1032($t0)
	
	sw $t4, -1020($t0)
	sw $t3, -1016($t0)
	
	# draw mouth
	sw $t3, -504($t0)
	sw $t3, -252($t0)
	sw $t3, -256($t0)
	sw $t3, -516($t0)
	
	# draw padding background
	sw $a1, 8($t0)
	sw $a1, -248($t0)
	sw $a1, -1272($t0)
	sw $a1, -1292($t0)
	sw $a1, -780($t0)
	sw $a1, -524($t0)
	sw $a1, -268($t0)
	sw $a1, -12($t0)
	
	lw $t5, heart + 8
	beq $t5, 1, draw_blush
	
	# parts of blush
	sw $t2, -772($t0)
	sw $t1, -760($t0)
	
	
	
	# following are for previous 32 x 64 screen size (units)
	#sw $t1, -136($t0)
	#sw $t1, -264($t0)
	#sw $t1, -392($t0)
	#sw $t1, -524($t0)
	#sw $t1, -648($t0)
	#sw $t1, -644($t0)
	#sw $t1, -640($t0)
	#sw $t1, -636($t0)
	#sw $t1, -380($t0)
	#sw $t1, -252($t0)
	
	
	#draw inside
	#sw $t2, -132($t0)
	#sw $t2, -256($t0)
	#sw $t2, -384($t0)
	#sw $t2, -388($t0)
	#sw $t2, -512($t0)
	
	#draw eyes
	#sw $t3, -516($t0)
	#sw $t4, -520($t0)
	
	#sw $t4, -508($t0)
	#sw $t3, -504($t0)
	
	#draw mouth
	#sw $t3, -248($t0)
	#sw $t3, -124($t0)
	#sw $t3, -128($t0)
	#sw $t3, -260($t0)
	
	#draw padding background
	#sw $a1, 8($t0)
	#sw $a1, -120($t0)
	#sw $a1, -376($t0)
	#sw $a1, -632($t0)
	#sw $a1, -652($t0)
	#sw $a1, -396($t0)
	#sw $a1, -268($t0)
	#sw $a1, -140($t0)
	#sw $a1, -12($t0)
	
	j draw_replacement
	
	draw_blush:
	
		li $t1, TOAST_BLUSH
	
		sw $t1, -772($t0)
		sw $t1, -760($t0)
		
		j draw_replacement
	
	draw_replacement:
	
		# do some fancy maths to overwrite last position, but not the part that overlaps with our current position
	
		addi $sp, $sp, -4
		sw $ra, 0($sp) # save $ra
	
		li $a0, BACKGROUND_COLOR
	
		bgt $s3, $s4, draw_replacement_moving_right
		blt $s3, $s4, draw_replacement_moving_left
		bgt $s3, $s5, draw_replacement_moving_down
		blt $s3, $s5, draw_replacement_moving_up
	
		#move $t7, $ra
		#jal refresh_screen
		#move $ra, $t7
	
		jr $ra
	
	draw_replacement_moving_right:
	
		#li $a0, 0x0000ff00
	
		# draw rect from old position top left, to current position bottom left
		
		addi $t0, $s3, DISPLAY_ADDR
		addi $t1, $s4, DISPLAY_ADDR
		
		addi $a1, $t1, -PLAYER_HEIGHT_ROW_OFFSET
		addi $a1, $a1, -12 # first address
		
		addi $a2, $t0, -16 # second address
		
		addi $a3, $t0, -PLAYER_HEIGHT_ROW_OFFSET
		addi $a3, $a3, -12
		sub $a3, $a3, $a1
		
		jal draw_rect
	
		blt $s3, $s4, draw_replacement_moving_left
		bgt $s3, $s5, draw_replacement_moving_down
		blt $s3, $s5, draw_replacement_moving_up
		
		lw $ra, 0($sp) # restore $ra
		addi $sp, $sp, 4
		
		jr $ra
		
	draw_replacement_moving_left:
	
		#li $a0, BACKGROUND_COLOR
	
		# draw rect from current position top right, to old position bottom right
	
		addi $t0, $s3, DISPLAY_ADDR
		addi $t1, $s4, DISPLAY_ADDR
		
		li $a3, PLAYER_WIDTH
		
		addi $a1, $t0, -PLAYER_HEIGHT_ROW_OFFSET
		addi $a1, $a1, 12
		
		addi $a2, $t1, 16
		
		jal draw_rect
	
		bgt $s3, $s5, draw_replacement_moving_down
		blt $s3, $s5, draw_replacement_moving_up
		
		lw $ra, 0($sp) # restore $ra
		addi $sp, $sp, 4
		
		jr $ra
	
	draw_replacement_moving_down:
	
		#li $a0, BACKGROUND_COLOR
	
		# draw rect from old position top left, to current position top right
		
		addi $t0, $s3, DISPLAY_ADDR
		addi $t1, $s5, DISPLAY_ADDR
		
		li $a3, PLAYER_WIDTH
		
		addi $a1, $t1, -PLAYER_HEIGHT_ROW_OFFSET
		addi $a1, $a1, -12 # first address
		
		addi $a2, $t0, -PLAYER_HEIGHT_ROW_OFFSET
		addi $a2, $a2, 8
		
		jal draw_rect
	
		blt $s3, $s5, draw_replacement_moving_up
		
		lw $ra, 0($sp) # restore $ra
		addi $sp, $sp, 4
		
		jr $ra
	
	draw_replacement_moving_up:
	
	
		#li $a0, BACKGROUND_COLOR
	
		# draw rect from current position left, to old position right
		
		li $a3, PLAYER_WIDTH
		# we need a bit extra for some trailing things that aren't being overwritten
		addi $a3, $a3, 4
		
		addi $t0, $s3, DISPLAY_ADDR
		addi $t1, $s5, DISPLAY_ADDR
		
		addi $a1, $t0, -12 
		addi $a1, $a1, ROW_END # first address
		
		addi $a2, $t1, 8

		jal draw_rect
		
		lw $ra, 0($sp) # restore $ra
		addi $sp, $sp, 4
	
		jr $ra
		
	
# $a0 = colour, $a1 = start address $a2 = end address, $a3 = row width	
draw_rect:
	
	move $t1, $a1 # move start address to $t1, this stores the current draw pixel
	
	add $t2, $t1, $a3 # get the end of the current row and put it in $t2 
	
	draw_pixel:
	
		bgt $t1, $a2, finish_draw_rect # if we pass the end address, finish
	
		bge $t1, $t2, next_row_draw_rect # see if we pass the end of the row 
	
		sw $a0, 0($t1) # color
	
		addi $t1, $t1, UNIT_SIZE # go to next pixel 
	
		j draw_pixel
	
	next_row_draw_rect:
	
		addi $t2, $t2, ROW_END # go to next row
		
		sub $t1, $t1, $a3 # go to start of row again
		addi $t1, $t1, ROW_END # go to next row start
		
		j draw_pixel
	
	finish_draw_rect:
		jr $ra
	
	
draw_lose_screen:

	li $t0, DISPLAY_ADDR
	
	lw $t7, coins_collected

	li $t1, 0x00ffffff
        li $t2, 0x004f4d4f
        li $t3, 0x00ff9800
        li $t4, 0x00f7ca45
        li $t5, 0x00ffc170
        li $t6, 0x00000000
        sw $t2, 0($t0)
        sw $t2, 4($t0)
        sw $t2, 8($t0)
        sw $t2, 12($t0)
        sw $t2, 16($t0)
        sw $t2, 20($t0)
        sw $t2, 24($t0)
        sw $t2, 28($t0)
        sw $t2, 32($t0)
        sw $t2, 36($t0)
        sw $t2, 40($t0)
        sw $t2, 44($t0)
        sw $t2, 48($t0)
        sw $t2, 52($t0)
        sw $t2, 56($t0)
        sw $t2, 60($t0)
        sw $t2, 64($t0)
        sw $t2, 68($t0)
        sw $t2, 72($t0)
        sw $t2, 76($t0)
        sw $t2, 80($t0)
        sw $t2, 84($t0)
        sw $t2, 88($t0)
        sw $t2, 92($t0)
        sw $t2, 96($t0)
        sw $t2, 100($t0)
        sw $t2, 104($t0)
        sw $t2, 108($t0)
        sw $t2, 112($t0)
        sw $t2, 116($t0)
        sw $t2, 120($t0)
        sw $t2, 124($t0)
        sw $t2, 128($t0)
        sw $t2, 132($t0)
        sw $t2, 136($t0)
        sw $t2, 140($t0)
        sw $t2, 144($t0)
        sw $t2, 148($t0)
        sw $t2, 152($t0)
        sw $t2, 156($t0)
        sw $t2, 160($t0)
        sw $t2, 164($t0)
        sw $t2, 168($t0)
        sw $t2, 172($t0)
        sw $t2, 176($t0)
        sw $t2, 180($t0)
        sw $t2, 184($t0)
        sw $t2, 188($t0)
        sw $t2, 192($t0)
        sw $t2, 196($t0)
        sw $t2, 200($t0)
        sw $t2, 204($t0)
        sw $t2, 208($t0)
        sw $t2, 212($t0)
        sw $t2, 216($t0)
        sw $t2, 220($t0)
        sw $t2, 224($t0)
        sw $t2, 228($t0)
        sw $t2, 232($t0)
        sw $t2, 236($t0)
        sw $t2, 240($t0)
        sw $t2, 244($t0)
        sw $t2, 248($t0)
        sw $t2, 252($t0)
        sw $t2, 256($t0)
        sw $t2, 260($t0)
        sw $t2, 264($t0)
        sw $t2, 268($t0)
        sw $t2, 272($t0)
        sw $t2, 276($t0)
        sw $t2, 280($t0)
        sw $t2, 284($t0)
        sw $t2, 288($t0)
        sw $t2, 292($t0)
        sw $t2, 296($t0)
        sw $t2, 300($t0)
        sw $t2, 304($t0)
        sw $t2, 308($t0)
        sw $t2, 312($t0)
        sw $t2, 316($t0)
        sw $t2, 320($t0)
        sw $t2, 324($t0)
        sw $t2, 328($t0)
        sw $t2, 332($t0)
        sw $t2, 336($t0)
        sw $t2, 340($t0)
        sw $t2, 344($t0)
        sw $t2, 348($t0)
        sw $t2, 352($t0)
        sw $t2, 356($t0)
        sw $t2, 360($t0)
        sw $t2, 364($t0)
        sw $t2, 368($t0)
        sw $t2, 372($t0)
        sw $t2, 376($t0)
        sw $t2, 380($t0)
        sw $t2, 384($t0)
        sw $t2, 388($t0)
        sw $t2, 392($t0)
        sw $t2, 396($t0)
        sw $t2, 400($t0)
        sw $t2, 404($t0)
        sw $t2, 408($t0)
        sw $t2, 412($t0)
        sw $t2, 416($t0)
        sw $t2, 420($t0)
        sw $t2, 424($t0)
        sw $t2, 428($t0)
        sw $t2, 432($t0)
        sw $t2, 436($t0)
        sw $t2, 440($t0)
        sw $t2, 444($t0)
        sw $t2, 448($t0)
        sw $t2, 452($t0)
        sw $t2, 456($t0)
        sw $t2, 460($t0)
        sw $t2, 464($t0)
        sw $t2, 468($t0)
        sw $t2, 472($t0)
        sw $t2, 476($t0)
        sw $t2, 480($t0)
        sw $t2, 484($t0)
        sw $t2, 488($t0)
        sw $t2, 492($t0)
        sw $t2, 496($t0)
        sw $t2, 500($t0)
        sw $t2, 504($t0)
        sw $t2, 508($t0)
        sw $t2, 512($t0)
        sw $t2, 516($t0)
        sw $t2, 520($t0)
        sw $t2, 524($t0)
        sw $t2, 528($t0)
        sw $t2, 532($t0)
        sw $t2, 536($t0)
        sw $t2, 540($t0)
        sw $t2, 544($t0)
        sw $t2, 548($t0)
        sw $t2, 552($t0)
        sw $t2, 556($t0)
        sw $t2, 560($t0)
        sw $t2, 564($t0)
        sw $t2, 568($t0)
        sw $t2, 572($t0)
        sw $t2, 576($t0)
        sw $t2, 580($t0)
        sw $t2, 584($t0)
        sw $t2, 588($t0)
        sw $t2, 592($t0)
        sw $t2, 596($t0)
        sw $t2, 600($t0)
        sw $t2, 604($t0)
        sw $t2, 608($t0)
        sw $t2, 612($t0)
        sw $t2, 616($t0)
        sw $t2, 620($t0)
        sw $t2, 624($t0)
        sw $t2, 628($t0)
        sw $t2, 632($t0)
        sw $t2, 636($t0)
        sw $t2, 640($t0)
        sw $t2, 644($t0)
        sw $t2, 648($t0)
        sw $t2, 652($t0)
        sw $t2, 656($t0)
        sw $t2, 660($t0)
        sw $t2, 664($t0)
        sw $t2, 668($t0)
        sw $t2, 672($t0)
        sw $t2, 676($t0)
        sw $t2, 680($t0)
        sw $t2, 684($t0)
        sw $t2, 688($t0)
        sw $t2, 692($t0)
        sw $t2, 696($t0)
        sw $t2, 700($t0)
        sw $t2, 704($t0)
        sw $t2, 708($t0)
        sw $t2, 712($t0)
        sw $t2, 716($t0)
        sw $t2, 720($t0)
        sw $t2, 724($t0)
        sw $t2, 728($t0)
        sw $t2, 732($t0)
        sw $t2, 736($t0)
        sw $t2, 740($t0)
        sw $t2, 744($t0)
        sw $t2, 748($t0)
        sw $t2, 752($t0)
        sw $t2, 756($t0)
        sw $t2, 760($t0)
        sw $t2, 764($t0)
        sw $t2, 768($t0)
        sw $t2, 772($t0)
        sw $t2, 776($t0)
        sw $t2, 780($t0)
        sw $t2, 784($t0)
        sw $t2, 788($t0)
        sw $t2, 792($t0)
        sw $t2, 796($t0)
        sw $t2, 800($t0)
        sw $t2, 804($t0)
        sw $t2, 808($t0)
        sw $t2, 812($t0)
        sw $t2, 816($t0)
        sw $t2, 820($t0)
        sw $t2, 824($t0)
        sw $t2, 828($t0)
        sw $t2, 832($t0)
        sw $t2, 836($t0)
        sw $t2, 840($t0)
        sw $t2, 844($t0)
        sw $t2, 848($t0)
        sw $t2, 852($t0)
        sw $t2, 856($t0)
        sw $t2, 860($t0)
        sw $t2, 864($t0)
        sw $t2, 868($t0)
        sw $t2, 872($t0)
        sw $t2, 876($t0)
        sw $t2, 880($t0)
        sw $t2, 884($t0)
        sw $t2, 888($t0)
        sw $t2, 892($t0)
        sw $t2, 896($t0)
        sw $t2, 900($t0)
        sw $t2, 904($t0)
        sw $t2, 908($t0)
        sw $t2, 912($t0)
        sw $t2, 916($t0)
        sw $t2, 920($t0)
        sw $t2, 924($t0)
        sw $t2, 928($t0)
        sw $t2, 932($t0)
        sw $t2, 936($t0)
        sw $t2, 940($t0)
        sw $t2, 944($t0)
        sw $t2, 948($t0)
        sw $t2, 952($t0)
        sw $t2, 956($t0)
        sw $t2, 960($t0)
        sw $t2, 964($t0)
        sw $t2, 968($t0)
        sw $t2, 972($t0)
        sw $t2, 976($t0)
        sw $t2, 980($t0)
        sw $t2, 984($t0)
        sw $t2, 988($t0)
        sw $t2, 992($t0)
        sw $t2, 996($t0)
        sw $t2, 1000($t0)
        sw $t2, 1004($t0)
        sw $t2, 1008($t0)
        sw $t2, 1012($t0)
        sw $t2, 1016($t0)
        sw $t2, 1020($t0)
        sw $t2, 1024($t0)
        sw $t2, 1028($t0)
        sw $t2, 1032($t0)
        sw $t2, 1036($t0)
        sw $t2, 1040($t0)
        sw $t2, 1044($t0)
        sw $t2, 1048($t0)
        sw $t2, 1052($t0)
        sw $t2, 1056($t0)
        sw $t2, 1060($t0)
        sw $t2, 1064($t0)
        sw $t2, 1068($t0)
        sw $t2, 1072($t0)
        sw $t2, 1076($t0)
        sw $t2, 1080($t0)
        sw $t2, 1084($t0)
        sw $t2, 1088($t0)
        sw $t2, 1092($t0)
        sw $t2, 1096($t0)
        sw $t2, 1100($t0)
        sw $t2, 1104($t0)
        sw $t2, 1108($t0)
        sw $t2, 1112($t0)
        sw $t2, 1116($t0)
        sw $t2, 1120($t0)
        sw $t2, 1124($t0)
        sw $t2, 1128($t0)
        sw $t2, 1132($t0)
        sw $t2, 1136($t0)
        sw $t2, 1140($t0)
        sw $t2, 1144($t0)
        sw $t2, 1148($t0)
        sw $t2, 1152($t0)
        sw $t2, 1156($t0)
        sw $t2, 1160($t0)
        sw $t2, 1164($t0)
        sw $t2, 1168($t0)
        sw $t2, 1172($t0)
        sw $t2, 1176($t0)
        sw $t2, 1180($t0)
        sw $t2, 1184($t0)
        sw $t2, 1188($t0)
        sw $t2, 1192($t0)
        sw $t2, 1196($t0)
        sw $t2, 1200($t0)
        sw $t2, 1204($t0)
        sw $t2, 1208($t0)
        sw $t2, 1212($t0)
        sw $t2, 1216($t0)
        sw $t2, 1220($t0)
        sw $t2, 1224($t0)
        sw $t2, 1228($t0)
        sw $t2, 1232($t0)
        sw $t2, 1236($t0)
        sw $t2, 1240($t0)
        sw $t2, 1244($t0)
        sw $t2, 1248($t0)
        sw $t2, 1252($t0)
        sw $t2, 1256($t0)
        sw $t2, 1260($t0)
        sw $t2, 1264($t0)
        sw $t2, 1268($t0)
        sw $t2, 1272($t0)
        sw $t2, 1276($t0)
        sw $t2, 1280($t0)
        sw $t2, 1284($t0)
        sw $t2, 1288($t0)
        sw $t2, 1292($t0)
        sw $t2, 1296($t0)
        sw $t2, 1300($t0)
        sw $t2, 1304($t0)
        sw $t2, 1308($t0)
        sw $t2, 1312($t0)
        sw $t2, 1316($t0)
        sw $t2, 1320($t0)
        sw $t2, 1324($t0)
        sw $t2, 1328($t0)
        sw $t2, 1332($t0)
        sw $t2, 1336($t0)
        sw $t2, 1340($t0)
        sw $t2, 1344($t0)
        sw $t2, 1348($t0)
        sw $t2, 1352($t0)
        sw $t2, 1356($t0)
        sw $t2, 1360($t0)
        sw $t2, 1364($t0)
        sw $t2, 1368($t0)
        sw $t2, 1372($t0)
        sw $t2, 1376($t0)
        sw $t2, 1380($t0)
        sw $t2, 1384($t0)
        sw $t2, 1388($t0)
        sw $t2, 1392($t0)
        sw $t2, 1396($t0)
        sw $t2, 1400($t0)
        sw $t2, 1404($t0)
        sw $t2, 1408($t0)
        sw $t2, 1412($t0)
        sw $t2, 1416($t0)
        sw $t2, 1420($t0)
        sw $t2, 1424($t0)
        sw $t2, 1428($t0)
        sw $t2, 1432($t0)
        sw $t2, 1436($t0)
        sw $t2, 1440($t0)
        sw $t2, 1444($t0)
        sw $t2, 1448($t0)
        sw $t2, 1452($t0)
        sw $t2, 1456($t0)
        sw $t2, 1460($t0)
        sw $t2, 1464($t0)
        sw $t2, 1468($t0)
        sw $t2, 1472($t0)
        sw $t2, 1476($t0)
        sw $t2, 1480($t0)
        sw $t2, 1484($t0)
        sw $t2, 1488($t0)
        sw $t2, 1492($t0)
        sw $t2, 1496($t0)
        sw $t2, 1500($t0)
        sw $t2, 1504($t0)
        sw $t2, 1508($t0)
        sw $t2, 1512($t0)
        sw $t2, 1516($t0)
        sw $t2, 1520($t0)
        sw $t2, 1524($t0)
        sw $t2, 1528($t0)
        sw $t2, 1532($t0)
        sw $t2, 1536($t0)
        sw $t2, 1540($t0)
        sw $t2, 1544($t0)
        sw $t2, 1548($t0)
        sw $t2, 1552($t0)
        sw $t2, 1556($t0)
        sw $t2, 1560($t0)
        sw $t2, 1564($t0)
        sw $t2, 1568($t0)
        sw $t2, 1572($t0)
        sw $t2, 1576($t0)
        sw $t2, 1580($t0)
        sw $t2, 1584($t0)
        sw $t2, 1588($t0)
        sw $t2, 1592($t0)
        sw $t2, 1596($t0)
        sw $t2, 1600($t0)
        sw $t2, 1604($t0)
        sw $t2, 1608($t0)
        sw $t2, 1612($t0)
        sw $t2, 1616($t0)
        sw $t2, 1620($t0)
        sw $t2, 1624($t0)
        sw $t2, 1628($t0)
        sw $t2, 1632($t0)
        sw $t2, 1636($t0)
        sw $t2, 1640($t0)
        sw $t2, 1644($t0)
        sw $t2, 1648($t0)
        sw $t2, 1652($t0)
        sw $t2, 1656($t0)
        sw $t2, 1660($t0)
        sw $t2, 1664($t0)
        sw $t2, 1668($t0)
        sw $t2, 1672($t0)
        sw $t2, 1676($t0)
        sw $t2, 1680($t0)
        sw $t2, 1684($t0)
        sw $t2, 1688($t0)
        sw $t2, 1692($t0)
        sw $t2, 1696($t0)
        sw $t2, 1700($t0)
        sw $t2, 1704($t0)
        sw $t2, 1708($t0)
        sw $t2, 1712($t0)
        sw $t2, 1716($t0)
        sw $t2, 1720($t0)
        sw $t2, 1724($t0)
        sw $t2, 1728($t0)
        sw $t2, 1732($t0)
        sw $t2, 1736($t0)
        sw $t2, 1740($t0)
        sw $t2, 1744($t0)
        sw $t2, 1748($t0)
        sw $t2, 1752($t0)
        sw $t2, 1756($t0)
        sw $t2, 1760($t0)
        sw $t2, 1764($t0)
        sw $t2, 1768($t0)
        sw $t2, 1772($t0)
        sw $t2, 1776($t0)
        sw $t2, 1780($t0)
        sw $t2, 1784($t0)
        sw $t2, 1788($t0)
        sw $t2, 1792($t0)
        sw $t2, 1796($t0)
        sw $t2, 1800($t0)
        sw $t2, 1804($t0)
        sw $t2, 1808($t0)
        sw $t2, 1812($t0)
        sw $t2, 1816($t0)
        sw $t2, 1820($t0)
        sw $t2, 1824($t0)
        sw $t2, 1828($t0)
        sw $t2, 1832($t0)
        sw $t2, 1836($t0)
        sw $t2, 1840($t0)
        sw $t2, 1844($t0)
        sw $t2, 1848($t0)
        sw $t2, 1852($t0)
        sw $t2, 1856($t0)
        sw $t2, 1860($t0)
        sw $t2, 1864($t0)
        sw $t2, 1868($t0)
        sw $t2, 1872($t0)
        sw $t2, 1876($t0)
        sw $t2, 1880($t0)
        sw $t2, 1884($t0)
        sw $t2, 1888($t0)
        sw $t2, 1892($t0)
        sw $t2, 1896($t0)
        sw $t2, 1900($t0)
        sw $t2, 1904($t0)
        sw $t2, 1908($t0)
        sw $t2, 1912($t0)
        sw $t2, 1916($t0)
        sw $t2, 1920($t0)
        sw $t2, 1924($t0)
        sw $t2, 1928($t0)
        sw $t2, 1932($t0)
        sw $t2, 1936($t0)
        sw $t2, 1940($t0)
        sw $t2, 1944($t0)
        sw $t2, 1948($t0)
        sw $t2, 1952($t0)
        sw $t2, 1956($t0)
        sw $t2, 1960($t0)
        sw $t2, 1964($t0)
        sw $t2, 1968($t0)
        sw $t2, 1972($t0)
        sw $t2, 1976($t0)
        sw $t2, 1980($t0)
        sw $t2, 1984($t0)
        sw $t2, 1988($t0)
        sw $t2, 1992($t0)
        sw $t2, 1996($t0)
        sw $t2, 2000($t0)
        sw $t2, 2004($t0)
        sw $t2, 2008($t0)
        sw $t2, 2012($t0)
        sw $t2, 2016($t0)
        sw $t2, 2020($t0)
        sw $t2, 2024($t0)
        sw $t2, 2028($t0)
        sw $t2, 2032($t0)
        sw $t2, 2036($t0)
        sw $t2, 2040($t0)
        sw $t2, 2044($t0)
        sw $t2, 2048($t0)
        sw $t2, 2052($t0)
        sw $t2, 2056($t0)
        sw $t2, 2060($t0)
        sw $t2, 2064($t0)
        sw $t2, 2068($t0)
        sw $t2, 2072($t0)
        sw $t2, 2076($t0)
        sw $t2, 2080($t0)
        sw $t2, 2084($t0)
        sw $t2, 2088($t0)
        sw $t2, 2092($t0)
        sw $t2, 2096($t0)
        sw $t2, 2100($t0)
        sw $t2, 2104($t0)
        sw $t2, 2108($t0)
        sw $t2, 2112($t0)
        sw $t2, 2116($t0)
        sw $t2, 2120($t0)
        sw $t2, 2124($t0)
        sw $t2, 2128($t0)
        sw $t2, 2132($t0)
        sw $t2, 2136($t0)
        sw $t2, 2140($t0)
        sw $t2, 2144($t0)
        sw $t2, 2148($t0)
        sw $t2, 2152($t0)
        sw $t2, 2156($t0)
        sw $t2, 2160($t0)
        sw $t2, 2164($t0)
        sw $t2, 2168($t0)
        sw $t2, 2172($t0)
        sw $t2, 2176($t0)
        sw $t2, 2180($t0)
        sw $t2, 2184($t0)
        sw $t2, 2188($t0)
        sw $t2, 2192($t0)
        sw $t2, 2196($t0)
        sw $t2, 2200($t0)
        sw $t2, 2204($t0)
        sw $t2, 2208($t0)
        sw $t2, 2212($t0)
        sw $t2, 2216($t0)
        sw $t2, 2220($t0)
        sw $t2, 2224($t0)
        sw $t2, 2228($t0)
        sw $t2, 2232($t0)
        sw $t2, 2236($t0)
        sw $t2, 2240($t0)
        sw $t2, 2244($t0)
        sw $t2, 2248($t0)
        sw $t2, 2252($t0)
        sw $t2, 2256($t0)
        sw $t2, 2260($t0)
        sw $t2, 2264($t0)
        sw $t2, 2268($t0)
        sw $t2, 2272($t0)
        sw $t2, 2276($t0)
        sw $t2, 2280($t0)
        sw $t2, 2284($t0)
        sw $t2, 2288($t0)
        sw $t2, 2292($t0)
        sw $t2, 2296($t0)
        sw $t2, 2300($t0)
        sw $t2, 2304($t0)
        sw $t2, 2308($t0)
        sw $t2, 2312($t0)
        sw $t2, 2316($t0)
        sw $t2, 2320($t0)
        sw $t2, 2324($t0)
        sw $t2, 2328($t0)
        sw $t2, 2332($t0)
        sw $t2, 2336($t0)
        sw $t2, 2340($t0)
        sw $t2, 2344($t0)
        sw $t2, 2348($t0)
        sw $t2, 2352($t0)
        sw $t2, 2356($t0)
        sw $t2, 2360($t0)
        sw $t2, 2364($t0)
        sw $t2, 2368($t0)
        sw $t2, 2372($t0)
        sw $t2, 2376($t0)
        sw $t2, 2380($t0)
        sw $t2, 2384($t0)
        sw $t2, 2388($t0)
        sw $t2, 2392($t0)
        sw $t2, 2396($t0)
        sw $t2, 2400($t0)
        sw $t2, 2404($t0)
        sw $t2, 2408($t0)
        sw $t2, 2412($t0)
        sw $t2, 2416($t0)
        sw $t2, 2420($t0)
        sw $t2, 2424($t0)
        sw $t2, 2428($t0)
        sw $t2, 2432($t0)
        sw $t2, 2436($t0)
        sw $t2, 2440($t0)
        sw $t2, 2444($t0)
        sw $t2, 2448($t0)
        sw $t2, 2452($t0)
        sw $t2, 2456($t0)
        sw $t2, 2460($t0)
        sw $t2, 2464($t0)
        sw $t2, 2468($t0)
        sw $t2, 2472($t0)
        sw $t2, 2476($t0)
        sw $t2, 2480($t0)
        sw $t2, 2484($t0)
        sw $t2, 2488($t0)
        sw $t2, 2492($t0)
        sw $t2, 2496($t0)
        sw $t2, 2500($t0)
        sw $t2, 2504($t0)
        sw $t2, 2508($t0)
        sw $t2, 2512($t0)
        sw $t2, 2516($t0)
        sw $t2, 2520($t0)
        sw $t2, 2524($t0)
        sw $t2, 2528($t0)
        sw $t2, 2532($t0)
        sw $t2, 2536($t0)
        sw $t2, 2540($t0)
        sw $t2, 2544($t0)
        sw $t2, 2548($t0)
        sw $t2, 2552($t0)
        sw $t2, 2556($t0)
        sw $t2, 2560($t0)
        sw $t2, 2564($t0)
        sw $t2, 2568($t0)
        sw $t2, 2572($t0)
        sw $t2, 2576($t0)
        sw $t2, 2580($t0)
        sw $t2, 2584($t0)
        sw $t2, 2588($t0)
        sw $t2, 2592($t0)
        sw $t2, 2596($t0)
        sw $t2, 2600($t0)
        sw $t2, 2604($t0)
        sw $t2, 2608($t0)
        sw $t2, 2612($t0)
        sw $t2, 2616($t0)
        sw $t2, 2620($t0)
        sw $t2, 2624($t0)
        sw $t2, 2628($t0)
        sw $t2, 2632($t0)
        sw $t2, 2636($t0)
        sw $t2, 2640($t0)
        sw $t2, 2644($t0)
        sw $t2, 2648($t0)
        sw $t2, 2652($t0)
        sw $t2, 2656($t0)
        sw $t2, 2660($t0)
        sw $t2, 2664($t0)
        sw $t2, 2668($t0)
        sw $t2, 2672($t0)
        sw $t2, 2676($t0)
        sw $t2, 2680($t0)
        sw $t2, 2684($t0)
        sw $t2, 2688($t0)
        sw $t2, 2692($t0)
        sw $t2, 2696($t0)
        sw $t2, 2700($t0)
        sw $t2, 2704($t0)
        sw $t2, 2708($t0)
        sw $t2, 2712($t0)
        sw $t2, 2716($t0)
        sw $t2, 2720($t0)
        sw $t2, 2724($t0)
        sw $t2, 2728($t0)
        sw $t2, 2732($t0)
        sw $t2, 2736($t0)
        sw $t2, 2740($t0)
        sw $t2, 2744($t0)
        sw $t2, 2748($t0)
        sw $t2, 2752($t0)
        sw $t2, 2756($t0)
        sw $t2, 2760($t0)
        sw $t2, 2764($t0)
        sw $t2, 2768($t0)
        sw $t2, 2772($t0)
        sw $t2, 2776($t0)
        sw $t2, 2780($t0)
        sw $t2, 2784($t0)
        sw $t2, 2788($t0)
        sw $t2, 2792($t0)
        sw $t2, 2796($t0)
        sw $t2, 2800($t0)
        sw $t2, 2804($t0)
        sw $t2, 2808($t0)
        sw $t2, 2812($t0)
        sw $t2, 2816($t0)
        sw $t2, 2820($t0)
        sw $t2, 2824($t0)
        sw $t2, 2828($t0)
        sw $t2, 2832($t0)
        sw $t2, 2836($t0)
        sw $t2, 2840($t0)
        sw $t2, 2844($t0)
        sw $t2, 2848($t0)
        sw $t2, 2852($t0)
        sw $t2, 2856($t0)
        sw $t2, 2860($t0)
        sw $t2, 2864($t0)
        sw $t2, 2868($t0)
        sw $t2, 2872($t0)
        sw $t2, 2876($t0)
        sw $t2, 2880($t0)
        sw $t2, 2884($t0)
        sw $t2, 2888($t0)
        sw $t2, 2892($t0)
        sw $t2, 2896($t0)
        sw $t2, 2900($t0)
        sw $t2, 2904($t0)
        sw $t2, 2908($t0)
        sw $t2, 2912($t0)
        sw $t2, 2916($t0)
        sw $t2, 2920($t0)
        sw $t2, 2924($t0)
        sw $t2, 2928($t0)
        sw $t2, 2932($t0)
        sw $t2, 2936($t0)
        sw $t2, 2940($t0)
        sw $t2, 2944($t0)
        sw $t2, 2948($t0)
        sw $t2, 2952($t0)
        sw $t2, 2956($t0)
        sw $t2, 2960($t0)
        sw $t2, 2964($t0)
        sw $t2, 2968($t0)
        sw $t2, 2972($t0)
        sw $t2, 2976($t0)
        sw $t2, 2980($t0)
        sw $t2, 2984($t0)
        sw $t2, 2988($t0)
        sw $t2, 2992($t0)
        sw $t2, 2996($t0)
        sw $t2, 3000($t0)
        sw $t2, 3004($t0)
        sw $t2, 3008($t0)
        sw $t2, 3012($t0)
        sw $t2, 3016($t0)
        sw $t2, 3020($t0)
        sw $t2, 3024($t0)
        sw $t2, 3028($t0)
        sw $t2, 3032($t0)
        sw $t2, 3036($t0)
        sw $t2, 3040($t0)
        sw $t2, 3044($t0)
        sw $t2, 3048($t0)
        sw $t2, 3052($t0)
        sw $t2, 3056($t0)
        sw $t2, 3060($t0)
        sw $t2, 3064($t0)
        sw $t2, 3068($t0)
        sw $t2, 3072($t0)
        sw $t2, 3076($t0)
        sw $t2, 3080($t0)
        sw $t2, 3084($t0)
        sw $t2, 3088($t0)
        sw $t2, 3092($t0)
        sw $t2, 3096($t0)
        sw $t2, 3100($t0)
        sw $t2, 3104($t0)
        sw $t2, 3108($t0)
        sw $t2, 3112($t0)
        sw $t2, 3116($t0)
        sw $t2, 3120($t0)
        sw $t2, 3124($t0)
        sw $t2, 3128($t0)
        sw $t2, 3132($t0)
        sw $t2, 3136($t0)
        sw $t2, 3140($t0)
        sw $t2, 3144($t0)
        sw $t2, 3148($t0)
        sw $t2, 3152($t0)
        sw $t2, 3156($t0)
        sw $t2, 3160($t0)
        sw $t2, 3164($t0)
        sw $t2, 3168($t0)
        sw $t2, 3172($t0)
        sw $t2, 3176($t0)
        sw $t2, 3180($t0)
        sw $t2, 3184($t0)
        sw $t2, 3188($t0)
        sw $t2, 3192($t0)
        sw $t2, 3196($t0)
        sw $t2, 3200($t0)
        sw $t2, 3204($t0)
        sw $t2, 3208($t0)
        sw $t2, 3212($t0)
        sw $t2, 3216($t0)
        sw $t2, 3220($t0)
        sw $t2, 3224($t0)
        sw $t2, 3228($t0)
        sw $t2, 3232($t0)
        sw $t2, 3236($t0)
        sw $t2, 3240($t0)
        sw $t2, 3244($t0)
        sw $t2, 3248($t0)
        sw $t2, 3252($t0)
        sw $t2, 3256($t0)
        sw $t2, 3260($t0)
        sw $t2, 3264($t0)
        sw $t2, 3268($t0)
        sw $t2, 3272($t0)
        sw $t2, 3276($t0)
        sw $t2, 3280($t0)
        sw $t2, 3284($t0)
        sw $t2, 3288($t0)
        sw $t2, 3292($t0)
        sw $t2, 3296($t0)
        sw $t2, 3300($t0)
        sw $t2, 3304($t0)
        sw $t2, 3308($t0)
        sw $t2, 3312($t0)
        sw $t2, 3316($t0)
        sw $t2, 3320($t0)
        sw $t2, 3324($t0)
        sw $t2, 3328($t0)
        sw $t2, 3332($t0)
        sw $t2, 3336($t0)
        sw $t2, 3340($t0)
        sw $t2, 3344($t0)
        sw $t2, 3348($t0)
        sw $t2, 3352($t0)
        sw $t2, 3356($t0)
        sw $t2, 3360($t0)
        sw $t2, 3364($t0)
        sw $t2, 3368($t0)
        sw $t2, 3372($t0)
        sw $t2, 3376($t0)
        sw $t2, 3380($t0)
        sw $t2, 3384($t0)
        sw $t2, 3388($t0)
        sw $t2, 3392($t0)
        sw $t2, 3396($t0)
        sw $t2, 3400($t0)
        sw $t2, 3404($t0)
        sw $t2, 3408($t0)
        sw $t2, 3412($t0)
        sw $t2, 3416($t0)
        sw $t2, 3420($t0)
        sw $t2, 3424($t0)
        sw $t2, 3428($t0)
        sw $t2, 3432($t0)
        sw $t2, 3436($t0)
        sw $t2, 3440($t0)
        sw $t2, 3444($t0)
        sw $t2, 3448($t0)
        sw $t2, 3452($t0)
        sw $t2, 3456($t0)
        sw $t2, 3460($t0)
        sw $t2, 3464($t0)
        sw $t2, 3468($t0)
        sw $t2, 3472($t0)
        sw $t2, 3476($t0)
        sw $t2, 3480($t0)
        sw $t2, 3484($t0)
        sw $t2, 3488($t0)
        sw $t2, 3492($t0)
        sw $t2, 3496($t0)
        sw $t2, 3500($t0)
        sw $t2, 3504($t0)
        sw $t2, 3508($t0)
        sw $t2, 3512($t0)
        sw $t2, 3516($t0)
        sw $t2, 3520($t0)
        sw $t2, 3524($t0)
        sw $t2, 3528($t0)
        sw $t2, 3532($t0)
        sw $t2, 3536($t0)
        sw $t2, 3540($t0)
        sw $t2, 3544($t0)
        sw $t2, 3548($t0)
        sw $t2, 3552($t0)
        sw $t2, 3556($t0)
        sw $t2, 3560($t0)
        sw $t2, 3564($t0)
        sw $t2, 3568($t0)
        sw $t2, 3572($t0)
        sw $t2, 3576($t0)
        sw $t2, 3580($t0)
        sw $t2, 3584($t0)
        sw $t2, 3588($t0)
        sw $t2, 3592($t0)
        sw $t2, 3596($t0)
        sw $t2, 3600($t0)
        sw $t2, 3604($t0)
        sw $t2, 3608($t0)
        sw $t2, 3612($t0)
        sw $t2, 3616($t0)
        sw $t2, 3620($t0)
        sw $t2, 3624($t0)
        sw $t2, 3628($t0)
        sw $t2, 3632($t0)
        sw $t2, 3636($t0)
        sw $t2, 3640($t0)
        sw $t2, 3644($t0)
        sw $t2, 3648($t0)
        sw $t2, 3652($t0)
        sw $t2, 3656($t0)
        sw $t2, 3660($t0)
        sw $t2, 3664($t0)
        sw $t2, 3668($t0)
        sw $t2, 3672($t0)
        sw $t2, 3676($t0)
        sw $t2, 3680($t0)
        sw $t2, 3684($t0)
        sw $t2, 3688($t0)
        sw $t2, 3692($t0)
        sw $t2, 3696($t0)
        sw $t2, 3700($t0)
        sw $t2, 3704($t0)
        sw $t2, 3708($t0)
        sw $t2, 3712($t0)
        sw $t2, 3716($t0)
        sw $t2, 3720($t0)
        sw $t2, 3724($t0)
        sw $t2, 3728($t0)
        sw $t2, 3732($t0)
        sw $t2, 3736($t0)
        sw $t2, 3740($t0)
        sw $t2, 3744($t0)
        sw $t2, 3748($t0)
        sw $t2, 3752($t0)
        sw $t2, 3756($t0)
        sw $t2, 3760($t0)
        sw $t2, 3764($t0)
        sw $t2, 3768($t0)
        sw $t2, 3772($t0)
        sw $t2, 3776($t0)
        sw $t2, 3780($t0)
        sw $t2, 3784($t0)
        sw $t2, 3788($t0)
        sw $t2, 3792($t0)
        sw $t2, 3796($t0)
        sw $t2, 3800($t0)
        sw $t2, 3804($t0)
        sw $t2, 3808($t0)
        sw $t2, 3812($t0)
        sw $t2, 3816($t0)
        sw $t2, 3820($t0)
        sw $t2, 3824($t0)
        sw $t2, 3828($t0)
        sw $t2, 3832($t0)
        sw $t2, 3836($t0)
        sw $t2, 3840($t0)
        sw $t2, 3844($t0)
        sw $t2, 3848($t0)
        sw $t2, 3852($t0)
        sw $t2, 3856($t0)
        sw $t2, 3860($t0)
        sw $t2, 3864($t0)
        sw $t2, 3868($t0)
        sw $t2, 3872($t0)
        sw $t2, 3876($t0)
        sw $t2, 3880($t0)
        sw $t2, 3884($t0)
        sw $t2, 3888($t0)
        sw $t2, 3892($t0)
        sw $t2, 3896($t0)
        sw $t2, 3900($t0)
        sw $t2, 3904($t0)
        sw $t2, 3908($t0)
        sw $t2, 3912($t0)
        sw $t2, 3916($t0)
        sw $t2, 3920($t0)
        sw $t2, 3924($t0)
        sw $t2, 3928($t0)
        sw $t2, 3932($t0)
        sw $t2, 3936($t0)
        sw $t2, 3940($t0)
        sw $t2, 3944($t0)
        sw $t2, 3948($t0)
        sw $t2, 3952($t0)
        sw $t2, 3956($t0)
        sw $t2, 3960($t0)
        sw $t2, 3964($t0)
        sw $t2, 3968($t0)
        sw $t2, 3972($t0)
        sw $t2, 3976($t0)
        sw $t2, 3980($t0)
        sw $t2, 3984($t0)
        sw $t2, 3988($t0)
        sw $t2, 3992($t0)
        sw $t2, 3996($t0)
        sw $t2, 4000($t0)
        sw $t2, 4004($t0)
        sw $t2, 4008($t0)
        sw $t2, 4012($t0)
        sw $t2, 4016($t0)
        sw $t2, 4020($t0)
        sw $t2, 4024($t0)
        sw $t2, 4028($t0)
        sw $t2, 4032($t0)
        sw $t2, 4036($t0)
        sw $t2, 4040($t0)
        sw $t2, 4044($t0)
        sw $t2, 4048($t0)
        sw $t2, 4052($t0)
        sw $t2, 4056($t0)
        sw $t2, 4060($t0)
        sw $t2, 4064($t0)
        sw $t2, 4068($t0)
        sw $t2, 4072($t0)
        sw $t2, 4076($t0)
        sw $t2, 4080($t0)
        sw $t2, 4084($t0)
        sw $t2, 4088($t0)
        sw $t2, 4092($t0)
        sw $t2, 4096($t0)
        sw $t2, 4100($t0)
        sw $t2, 4104($t0)
        sw $t2, 4108($t0)
        sw $t2, 4112($t0)
        sw $t2, 4116($t0)
        sw $t2, 4120($t0)
        sw $t2, 4124($t0)
        sw $t2, 4128($t0)
        sw $t2, 4132($t0)
        sw $t2, 4136($t0)
        sw $t2, 4140($t0)
        sw $t2, 4144($t0)
        sw $t2, 4148($t0)
        sw $t2, 4152($t0)
        sw $t2, 4156($t0)
        sw $t2, 4160($t0)
        sw $t2, 4164($t0)
        sw $t2, 4168($t0)
        sw $t2, 4172($t0)
        sw $t2, 4176($t0)
        sw $t2, 4180($t0)
        sw $t2, 4184($t0)
        sw $t2, 4188($t0)
        sw $t2, 4192($t0)
        sw $t2, 4196($t0)
        sw $t2, 4200($t0)
        sw $t2, 4204($t0)
        sw $t2, 4208($t0)
        sw $t2, 4212($t0)
        sw $t2, 4216($t0)
        sw $t2, 4220($t0)
        sw $t2, 4224($t0)
        sw $t2, 4228($t0)
        sw $t2, 4232($t0)
        sw $t2, 4236($t0)
        sw $t2, 4240($t0)
        sw $t2, 4244($t0)
        sw $t2, 4248($t0)
        sw $t2, 4252($t0)
        sw $t2, 4256($t0)
        sw $t2, 4260($t0)
        sw $t2, 4264($t0)
        sw $t2, 4268($t0)
        sw $t2, 4272($t0)
        sw $t2, 4276($t0)
        sw $t2, 4280($t0)
        sw $t2, 4284($t0)
        sw $t2, 4288($t0)
        sw $t2, 4292($t0)
        sw $t2, 4296($t0)
        sw $t2, 4300($t0)
        sw $t2, 4304($t0)
        sw $t2, 4308($t0)
        sw $t2, 4312($t0)
        sw $t2, 4316($t0)
        sw $t2, 4320($t0)
        sw $t2, 4324($t0)
        sw $t2, 4328($t0)
        sw $t2, 4332($t0)
        sw $t2, 4336($t0)
        sw $t2, 4340($t0)
        sw $t2, 4344($t0)
        sw $t2, 4348($t0)
        sw $t2, 4352($t0)
        sw $t2, 4356($t0)
        sw $t2, 4360($t0)
        sw $t2, 4364($t0)
        sw $t2, 4368($t0)
        sw $t2, 4372($t0)
        sw $t2, 4376($t0)
        sw $t2, 4380($t0)
        sw $t2, 4384($t0)
        sw $t2, 4388($t0)
        sw $t2, 4392($t0)
        sw $t2, 4396($t0)
        sw $t2, 4400($t0)
        sw $t2, 4404($t0)
        sw $t2, 4408($t0)
        sw $t2, 4412($t0)
        sw $t2, 4416($t0)
        sw $t2, 4420($t0)
        sw $t2, 4424($t0)
        sw $t2, 4428($t0)
        sw $t2, 4432($t0)
        sw $t2, 4436($t0)
        sw $t2, 4440($t0)
        sw $t2, 4444($t0)
        sw $t2, 4448($t0)
        sw $t2, 4452($t0)
        sw $t2, 4456($t0)
        sw $t2, 4460($t0)
        sw $t2, 4464($t0)
        sw $t2, 4468($t0)
        sw $t2, 4472($t0)
        sw $t2, 4476($t0)
        sw $t2, 4480($t0)
        sw $t2, 4484($t0)
        sw $t2, 4488($t0)
        sw $t2, 4492($t0)
        sw $t2, 4496($t0)
        sw $t2, 4500($t0)
        sw $t2, 4504($t0)
        sw $t2, 4508($t0)
        sw $t2, 4512($t0)
        sw $t2, 4516($t0)
        sw $t2, 4520($t0)
        sw $t2, 4524($t0)
        sw $t2, 4528($t0)
        sw $t2, 4532($t0)
        sw $t2, 4536($t0)
        sw $t2, 4540($t0)
        sw $t2, 4544($t0)
        sw $t2, 4548($t0)
        sw $t2, 4552($t0)
        sw $t2, 4556($t0)
        sw $t2, 4560($t0)
        sw $t2, 4564($t0)
        sw $t2, 4568($t0)
        sw $t2, 4572($t0)
        sw $t2, 4576($t0)
        sw $t2, 4580($t0)
        sw $t2, 4584($t0)
        sw $t2, 4588($t0)
        sw $t2, 4592($t0)
        sw $t2, 4596($t0)
        sw $t2, 4600($t0)
        sw $t2, 4604($t0)
        sw $t2, 4608($t0)
        sw $t2, 4612($t0)
        sw $t2, 4616($t0)
        sw $t2, 4620($t0)
        sw $t2, 4624($t0)
        sw $t2, 4628($t0)
        sw $t2, 4632($t0)
        sw $t2, 4636($t0)
        sw $t1, 4640($t0)
        sw $t2, 4644($t0)
        sw $t2, 4648($t0)
        sw $t2, 4652($t0)
        sw $t1, 4656($t0)
        sw $t2, 4660($t0)
        sw $t2, 4664($t0)
        sw $t1, 4668($t0)
        sw $t1, 4672($t0)
        sw $t1, 4676($t0)
        sw $t1, 4680($t0)
        sw $t1, 4684($t0)
        sw $t2, 4688($t0)
        sw $t2, 4692($t0)
        sw $t1, 4696($t0)
        sw $t2, 4700($t0)
        sw $t2, 4704($t0)
        sw $t2, 4708($t0)
        sw $t1, 4712($t0)
        sw $t2, 4716($t0)
        sw $t2, 4720($t0)
        sw $t2, 4724($t0)
        sw $t2, 4728($t0)
        sw $t2, 4732($t0)
        sw $t2, 4736($t0)
        sw $t2, 4740($t0)
        sw $t1, 4744($t0)
        sw $t2, 4748($t0)
        sw $t2, 4752($t0)
        sw $t2, 4756($t0)
        sw $t2, 4760($t0)
        sw $t2, 4764($t0)
        sw $t1, 4768($t0)
        sw $t1, 4772($t0)
        sw $t1, 4776($t0)
        sw $t1, 4780($t0)
        sw $t2, 4784($t0)
        sw $t2, 4788($t0)
        sw $t1, 4792($t0)
        sw $t1, 4796($t0)
        sw $t1, 4800($t0)
        sw $t1, 4804($t0)
        sw $t2, 4808($t0)
        sw $t2, 4812($t0)
        sw $t1, 4816($t0)
        sw $t1, 4820($t0)
        sw $t1, 4824($t0)
        sw $t1, 4828($t0)
        sw $t1, 4832($t0)
        sw $t2, 4836($t0)
        sw $t2, 4840($t0)
        sw $t2, 4844($t0)
        sw $t2, 4848($t0)
        sw $t2, 4852($t0)
        sw $t2, 4856($t0)
        sw $t2, 4860($t0)
        sw $t2, 4864($t0)
        sw $t2, 4868($t0)
        sw $t2, 4872($t0)
        sw $t2, 4876($t0)
        sw $t2, 4880($t0)
        sw $t2, 4884($t0)
        sw $t2, 4888($t0)
        sw $t2, 4892($t0)
        sw $t1, 4896($t0)
        sw $t2, 4900($t0)
        sw $t2, 4904($t0)
        sw $t2, 4908($t0)
        sw $t1, 4912($t0)
        sw $t2, 4916($t0)
        sw $t2, 4920($t0)
        sw $t1, 4924($t0)
        sw $t2, 4928($t0)
        sw $t2, 4932($t0)
        sw $t2, 4936($t0)
        sw $t1, 4940($t0)
        sw $t2, 4944($t0)
        sw $t2, 4948($t0)
        sw $t1, 4952($t0)
        sw $t2, 4956($t0)
        sw $t2, 4960($t0)
        sw $t2, 4964($t0)
        sw $t1, 4968($t0)
        sw $t2, 4972($t0)
        sw $t2, 4976($t0)
        sw $t2, 4980($t0)
        sw $t2, 4984($t0)
        sw $t2, 4988($t0)
        sw $t2, 4992($t0)
        sw $t2, 4996($t0)
        sw $t1, 5000($t0)
        sw $t2, 5004($t0)
        sw $t2, 5008($t0)
        sw $t2, 5012($t0)
        sw $t2, 5016($t0)
        sw $t2, 5020($t0)
        sw $t1, 5024($t0)
        sw $t2, 5028($t0)
        sw $t2, 5032($t0)
        sw $t1, 5036($t0)
        sw $t2, 5040($t0)
        sw $t2, 5044($t0)
        sw $t1, 5048($t0)
        sw $t2, 5052($t0)
        sw $t2, 5056($t0)
        sw $t2, 5060($t0)
        sw $t2, 5064($t0)
        sw $t2, 5068($t0)
        sw $t2, 5072($t0)
        sw $t2, 5076($t0)
        sw $t1, 5080($t0)
        sw $t2, 5084($t0)
        sw $t2, 5088($t0)
        sw $t2, 5092($t0)
        sw $t2, 5096($t0)
        sw $t2, 5100($t0)
        sw $t2, 5104($t0)
        sw $t2, 5108($t0)
        sw $t2, 5112($t0)
        sw $t2, 5116($t0)
        sw $t2, 5120($t0)
        sw $t2, 5124($t0)
        sw $t2, 5128($t0)
        sw $t2, 5132($t0)
        sw $t2, 5136($t0)
        sw $t2, 5140($t0)
        sw $t2, 5144($t0)
        sw $t2, 5148($t0)
        sw $t2, 5152($t0)
        sw $t1, 5156($t0)
        sw $t1, 5160($t0)
        sw $t1, 5164($t0)
        sw $t2, 5168($t0)
        sw $t2, 5172($t0)
        sw $t2, 5176($t0)
        sw $t1, 5180($t0)
        sw $t2, 5184($t0)
        sw $t2, 5188($t0)
        sw $t2, 5192($t0)
        sw $t1, 5196($t0)
        sw $t2, 5200($t0)
        sw $t2, 5204($t0)
        sw $t1, 5208($t0)
        sw $t2, 5212($t0)
        sw $t2, 5216($t0)
        sw $t2, 5220($t0)
        sw $t1, 5224($t0)
        sw $t2, 5228($t0)
        sw $t2, 5232($t0)
        sw $t2, 5236($t0)
        sw $t2, 5240($t0)
        sw $t2, 5244($t0)
        sw $t2, 5248($t0)
        sw $t2, 5252($t0)
        sw $t1, 5256($t0)
        sw $t2, 5260($t0)
        sw $t2, 5264($t0)
        sw $t2, 5268($t0)
        sw $t2, 5272($t0)
        sw $t2, 5276($t0)
        sw $t1, 5280($t0)
        sw $t2, 5284($t0)
        sw $t2, 5288($t0)
        sw $t1, 5292($t0)
        sw $t2, 5296($t0)
        sw $t2, 5300($t0)
        sw $t1, 5304($t0)
        sw $t2, 5308($t0)
        sw $t2, 5312($t0)
        sw $t2, 5316($t0)
        sw $t2, 5320($t0)
        sw $t2, 5324($t0)
        sw $t2, 5328($t0)
        sw $t2, 5332($t0)
        sw $t1, 5336($t0)
        sw $t2, 5340($t0)
        sw $t2, 5344($t0)
        sw $t2, 5348($t0)
        sw $t2, 5352($t0)
        sw $t2, 5356($t0)
        sw $t2, 5360($t0)
        sw $t2, 5364($t0)
        sw $t2, 5368($t0)
        sw $t2, 5372($t0)
        sw $t2, 5376($t0)
        sw $t2, 5380($t0)
        sw $t2, 5384($t0)
        sw $t2, 5388($t0)
        sw $t2, 5392($t0)
        sw $t2, 5396($t0)
        sw $t2, 5400($t0)
        sw $t2, 5404($t0)
        sw $t2, 5408($t0)
        sw $t2, 5412($t0)
        sw $t1, 5416($t0)
        sw $t2, 5420($t0)
        sw $t2, 5424($t0)
        sw $t2, 5428($t0)
        sw $t2, 5432($t0)
        sw $t1, 5436($t0)
        sw $t2, 5440($t0)
        sw $t2, 5444($t0)
        sw $t2, 5448($t0)
        sw $t1, 5452($t0)
        sw $t2, 5456($t0)
        sw $t2, 5460($t0)
        sw $t1, 5464($t0)
        sw $t2, 5468($t0)
        sw $t2, 5472($t0)
        sw $t2, 5476($t0)
        sw $t1, 5480($t0)
        sw $t2, 5484($t0)
        sw $t2, 5488($t0)
        sw $t2, 5492($t0)
        sw $t2, 5496($t0)
        sw $t2, 5500($t0)
        sw $t2, 5504($t0)
        sw $t2, 5508($t0)
        sw $t1, 5512($t0)
        sw $t2, 5516($t0)
        sw $t2, 5520($t0)
        sw $t2, 5524($t0)
        sw $t2, 5528($t0)
        sw $t2, 5532($t0)
        sw $t1, 5536($t0)
        sw $t2, 5540($t0)
        sw $t2, 5544($t0)
        sw $t1, 5548($t0)
        sw $t2, 5552($t0)
        sw $t2, 5556($t0)
        sw $t1, 5560($t0)
        sw $t1, 5564($t0)
        sw $t1, 5568($t0)
        sw $t1, 5572($t0)
        sw $t2, 5576($t0)
        sw $t2, 5580($t0)
        sw $t2, 5584($t0)
        sw $t2, 5588($t0)
        sw $t1, 5592($t0)
        sw $t2, 5596($t0)
        sw $t2, 5600($t0)
        sw $t2, 5604($t0)
        sw $t2, 5608($t0)
        sw $t2, 5612($t0)
        sw $t2, 5616($t0)
        sw $t2, 5620($t0)
        sw $t2, 5624($t0)
        sw $t2, 5628($t0)
        sw $t2, 5632($t0)
        sw $t2, 5636($t0)
        sw $t2, 5640($t0)
        sw $t2, 5644($t0)
        sw $t2, 5648($t0)
        sw $t2, 5652($t0)
        sw $t2, 5656($t0)
        sw $t2, 5660($t0)
        sw $t2, 5664($t0)
        sw $t2, 5668($t0)
        sw $t1, 5672($t0)
        sw $t2, 5676($t0)
        sw $t2, 5680($t0)
        sw $t2, 5684($t0)
        sw $t2, 5688($t0)
        sw $t1, 5692($t0)
        sw $t2, 5696($t0)
        sw $t2, 5700($t0)
        sw $t2, 5704($t0)
        sw $t1, 5708($t0)
        sw $t2, 5712($t0)
        sw $t2, 5716($t0)
        sw $t1, 5720($t0)
        sw $t2, 5724($t0)
        sw $t2, 5728($t0)
        sw $t2, 5732($t0)
        sw $t1, 5736($t0)
        sw $t2, 5740($t0)
        sw $t2, 5744($t0)
        sw $t2, 5748($t0)
        sw $t2, 5752($t0)
        sw $t2, 5756($t0)
        sw $t2, 5760($t0)
        sw $t2, 5764($t0)
        sw $t1, 5768($t0)
        sw $t2, 5772($t0)
        sw $t2, 5776($t0)
        sw $t2, 5780($t0)
        sw $t2, 5784($t0)
        sw $t2, 5788($t0)
        sw $t1, 5792($t0)
        sw $t2, 5796($t0)
        sw $t2, 5800($t0)
        sw $t1, 5804($t0)
        sw $t2, 5808($t0)
        sw $t2, 5812($t0)
        sw $t2, 5816($t0)
        sw $t2, 5820($t0)
        sw $t2, 5824($t0)
        sw $t1, 5828($t0)
        sw $t2, 5832($t0)
        sw $t2, 5836($t0)
        sw $t2, 5840($t0)
        sw $t2, 5844($t0)
        sw $t1, 5848($t0)
        sw $t2, 5852($t0)
        sw $t2, 5856($t0)
        sw $t2, 5860($t0)
        sw $t2, 5864($t0)
        sw $t2, 5868($t0)
        sw $t2, 5872($t0)
        sw $t2, 5876($t0)
        sw $t2, 5880($t0)
        sw $t2, 5884($t0)
        sw $t2, 5888($t0)
        sw $t2, 5892($t0)
        sw $t2, 5896($t0)
        sw $t2, 5900($t0)
        sw $t2, 5904($t0)
        sw $t2, 5908($t0)
        sw $t2, 5912($t0)
        sw $t2, 5916($t0)
        sw $t2, 5920($t0)
        sw $t2, 5924($t0)
        sw $t1, 5928($t0)
        sw $t2, 5932($t0)
        sw $t2, 5936($t0)
        sw $t2, 5940($t0)
        sw $t2, 5944($t0)
        sw $t1, 5948($t0)
        sw $t2, 5952($t0)
        sw $t2, 5956($t0)
        sw $t2, 5960($t0)
        sw $t1, 5964($t0)
        sw $t2, 5968($t0)
        sw $t2, 5972($t0)
        sw $t1, 5976($t0)
        sw $t2, 5980($t0)
        sw $t2, 5984($t0)
        sw $t2, 5988($t0)
        sw $t1, 5992($t0)
        sw $t2, 5996($t0)
        sw $t2, 6000($t0)
        sw $t2, 6004($t0)
        sw $t2, 6008($t0)
        sw $t2, 6012($t0)
        sw $t2, 6016($t0)
        sw $t2, 6020($t0)
        sw $t1, 6024($t0)
        sw $t2, 6028($t0)
        sw $t2, 6032($t0)
        sw $t2, 6036($t0)
        sw $t2, 6040($t0)
        sw $t2, 6044($t0)
        sw $t1, 6048($t0)
        sw $t2, 6052($t0)
        sw $t2, 6056($t0)
        sw $t1, 6060($t0)
        sw $t2, 6064($t0)
        sw $t2, 6068($t0)
        sw $t2, 6072($t0)
        sw $t2, 6076($t0)
        sw $t2, 6080($t0)
        sw $t1, 6084($t0)
        sw $t2, 6088($t0)
        sw $t2, 6092($t0)
        sw $t2, 6096($t0)
        sw $t2, 6100($t0)
        sw $t1, 6104($t0)
        sw $t2, 6108($t0)
        sw $t2, 6112($t0)
        sw $t2, 6116($t0)
        sw $t2, 6120($t0)
        sw $t2, 6124($t0)
        sw $t2, 6128($t0)
        sw $t2, 6132($t0)
        sw $t2, 6136($t0)
        sw $t2, 6140($t0)
        sw $t2, 6144($t0)
        sw $t2, 6148($t0)
        sw $t2, 6152($t0)
        sw $t2, 6156($t0)
        sw $t2, 6160($t0)
        sw $t2, 6164($t0)
        sw $t2, 6168($t0)
        sw $t2, 6172($t0)
        sw $t2, 6176($t0)
        sw $t2, 6180($t0)
        sw $t1, 6184($t0)
        sw $t2, 6188($t0)
        sw $t2, 6192($t0)
        sw $t2, 6196($t0)
        sw $t2, 6200($t0)
        sw $t1, 6204($t0)
        sw $t1, 6208($t0)
        sw $t1, 6212($t0)
        sw $t1, 6216($t0)
        sw $t1, 6220($t0)
        sw $t2, 6224($t0)
        sw $t2, 6228($t0)
        sw $t1, 6232($t0)
        sw $t1, 6236($t0)
        sw $t1, 6240($t0)
        sw $t1, 6244($t0)
        sw $t1, 6248($t0)
        sw $t2, 6252($t0)
        sw $t2, 6256($t0)
        sw $t2, 6260($t0)
        sw $t2, 6264($t0)
        sw $t2, 6268($t0)
        sw $t2, 6272($t0)
        sw $t2, 6276($t0)
        sw $t1, 6280($t0)
        sw $t1, 6284($t0)
        sw $t1, 6288($t0)
        sw $t1, 6292($t0)
        sw $t2, 6296($t0)
        sw $t2, 6300($t0)
        sw $t1, 6304($t0)
        sw $t1, 6308($t0)
        sw $t1, 6312($t0)
        sw $t1, 6316($t0)
        sw $t2, 6320($t0)
        sw $t2, 6324($t0)
        sw $t1, 6328($t0)
        sw $t1, 6332($t0)
        sw $t1, 6336($t0)
        sw $t1, 6340($t0)
        sw $t2, 6344($t0)
        sw $t2, 6348($t0)
        sw $t2, 6352($t0)
        sw $t2, 6356($t0)
        sw $t1, 6360($t0)
        sw $t2, 6364($t0)
        sw $t2, 6368($t0)
        sw $t2, 6372($t0)
        sw $t2, 6376($t0)
        sw $t2, 6380($t0)
        sw $t2, 6384($t0)
        sw $t2, 6388($t0)
        sw $t2, 6392($t0)
        sw $t2, 6396($t0)
        sw $t2, 6400($t0)
        sw $t2, 6404($t0)
        sw $t2, 6408($t0)
        sw $t2, 6412($t0)
        sw $t2, 6416($t0)
        sw $t2, 6420($t0)
        sw $t2, 6424($t0)
        sw $t2, 6428($t0)
        sw $t2, 6432($t0)
        sw $t2, 6436($t0)
        sw $t2, 6440($t0)
        sw $t2, 6444($t0)
        sw $t2, 6448($t0)
        sw $t2, 6452($t0)
        sw $t2, 6456($t0)
        sw $t2, 6460($t0)
        sw $t2, 6464($t0)
        sw $t2, 6468($t0)
        sw $t2, 6472($t0)
        sw $t2, 6476($t0)
        sw $t2, 6480($t0)
        sw $t2, 6484($t0)
        sw $t2, 6488($t0)
        sw $t2, 6492($t0)
        sw $t2, 6496($t0)
        sw $t2, 6500($t0)
        sw $t2, 6504($t0)
        sw $t2, 6508($t0)
        sw $t2, 6512($t0)
        sw $t2, 6516($t0)
        sw $t2, 6520($t0)
        sw $t2, 6524($t0)
        sw $t2, 6528($t0)
        sw $t2, 6532($t0)
        sw $t2, 6536($t0)
        sw $t2, 6540($t0)
        sw $t2, 6544($t0)
        sw $t2, 6548($t0)
        sw $t2, 6552($t0)
        sw $t2, 6556($t0)
        sw $t2, 6560($t0)
        sw $t2, 6564($t0)
        sw $t2, 6568($t0)
        sw $t2, 6572($t0)
        sw $t2, 6576($t0)
        sw $t2, 6580($t0)
        sw $t2, 6584($t0)
        sw $t2, 6588($t0)
        sw $t2, 6592($t0)
        sw $t2, 6596($t0)
        sw $t2, 6600($t0)
        sw $t2, 6604($t0)
        sw $t2, 6608($t0)
        sw $t2, 6612($t0)
        sw $t2, 6616($t0)
        sw $t2, 6620($t0)
        sw $t2, 6624($t0)
        sw $t2, 6628($t0)
        sw $t2, 6632($t0)
        sw $t2, 6636($t0)
        sw $t2, 6640($t0)
        sw $t2, 6644($t0)
        sw $t2, 6648($t0)
        sw $t2, 6652($t0)
        sw $t2, 6656($t0)
        sw $t2, 6660($t0)
        sw $t2, 6664($t0)
        sw $t2, 6668($t0)
        sw $t2, 6672($t0)
        sw $t2, 6676($t0)
        sw $t2, 6680($t0)
        sw $t2, 6684($t0)
        sw $t2, 6688($t0)
        sw $t2, 6692($t0)
        sw $t2, 6696($t0)
        sw $t2, 6700($t0)
        sw $t2, 6704($t0)
        sw $t2, 6708($t0)
        sw $t2, 6712($t0)
        sw $t2, 6716($t0)
        sw $t2, 6720($t0)
        sw $t2, 6724($t0)
        sw $t2, 6728($t0)
        sw $t2, 6732($t0)
        sw $t2, 6736($t0)
        sw $t2, 6740($t0)
        sw $t2, 6744($t0)
        sw $t2, 6748($t0)
        sw $t2, 6752($t0)
        sw $t2, 6756($t0)
        sw $t2, 6760($t0)
        sw $t2, 6764($t0)
        sw $t2, 6768($t0)
        sw $t2, 6772($t0)
        sw $t2, 6776($t0)
        sw $t2, 6780($t0)
        sw $t2, 6784($t0)
        sw $t2, 6788($t0)
        sw $t2, 6792($t0)
        sw $t2, 6796($t0)
        sw $t2, 6800($t0)
        sw $t2, 6804($t0)
        sw $t2, 6808($t0)
        sw $t2, 6812($t0)
        sw $t2, 6816($t0)
        sw $t2, 6820($t0)
        sw $t2, 6824($t0)
        sw $t2, 6828($t0)
        sw $t2, 6832($t0)
        sw $t2, 6836($t0)
        sw $t2, 6840($t0)
        sw $t2, 6844($t0)
        sw $t2, 6848($t0)
        sw $t2, 6852($t0)
        sw $t2, 6856($t0)
        sw $t2, 6860($t0)
        sw $t2, 6864($t0)
        sw $t2, 6868($t0)
        sw $t2, 6872($t0)
        sw $t2, 6876($t0)
        sw $t2, 6880($t0)
        sw $t2, 6884($t0)
        sw $t2, 6888($t0)
        sw $t2, 6892($t0)
        sw $t2, 6896($t0)
        sw $t2, 6900($t0)
        sw $t2, 6904($t0)
        sw $t2, 6908($t0)
        sw $t2, 6912($t0)
        sw $t2, 6916($t0)
        sw $t2, 6920($t0)
        sw $t2, 6924($t0)
        sw $t2, 6928($t0)
        sw $t2, 6932($t0)
        sw $t2, 6936($t0)
        sw $t2, 6940($t0)
        sw $t2, 6944($t0)
        sw $t2, 6948($t0)
        sw $t2, 6952($t0)
        sw $t2, 6956($t0)
        sw $t2, 6960($t0)
        sw $t2, 6964($t0)
        sw $t2, 6968($t0)
        sw $t2, 6972($t0)
        sw $t2, 6976($t0)
        sw $t2, 6980($t0)
        sw $t2, 6984($t0)
        sw $t2, 6988($t0)
        sw $t2, 6992($t0)
        sw $t2, 6996($t0)
        sw $t2, 7000($t0)
        sw $t2, 7004($t0)
        sw $t2, 7008($t0)
        sw $t2, 7012($t0)
        sw $t2, 7016($t0)
        sw $t2, 7020($t0)
        sw $t2, 7024($t0)
        sw $t2, 7028($t0)
        sw $t2, 7032($t0)
        sw $t2, 7036($t0)
        sw $t2, 7040($t0)
        sw $t2, 7044($t0)
        sw $t2, 7048($t0)
        sw $t2, 7052($t0)
        sw $t2, 7056($t0)
        sw $t2, 7060($t0)
        sw $t2, 7064($t0)
        sw $t2, 7068($t0)
        sw $t2, 7072($t0)
        sw $t2, 7076($t0)
        sw $t2, 7080($t0)
        sw $t2, 7084($t0)
        sw $t2, 7088($t0)
        sw $t2, 7092($t0)
        sw $t2, 7096($t0)
        sw $t2, 7100($t0)
        sw $t2, 7104($t0)
        sw $t2, 7108($t0)
        sw $t2, 7112($t0)
        sw $t2, 7116($t0)
        sw $t2, 7120($t0)
        sw $t2, 7124($t0)
        sw $t2, 7128($t0)
        sw $t2, 7132($t0)
        sw $t2, 7136($t0)
        sw $t2, 7140($t0)
        sw $t2, 7144($t0)
        sw $t2, 7148($t0)
        sw $t2, 7152($t0)
        sw $t2, 7156($t0)
        sw $t2, 7160($t0)
        sw $t2, 7164($t0)
        sw $t2, 7168($t0)
        sw $t2, 7172($t0)
        sw $t2, 7176($t0)
        sw $t2, 7180($t0)
        sw $t2, 7184($t0)
        sw $t2, 7188($t0)
        sw $t2, 7192($t0)
        sw $t2, 7196($t0)
        sw $t2, 7200($t0)
        sw $t2, 7204($t0)
        sw $t2, 7208($t0)
        sw $t2, 7212($t0)
        sw $t2, 7216($t0)
        sw $t2, 7220($t0)
        sw $t2, 7224($t0)
        sw $t2, 7228($t0)
        sw $t2, 7232($t0)
        sw $t2, 7236($t0)
        sw $t2, 7240($t0)
        sw $t2, 7244($t0)
        sw $t2, 7248($t0)
        sw $t2, 7252($t0)
        sw $t2, 7256($t0)
        sw $t2, 7260($t0)
        sw $t2, 7264($t0)
        sw $t2, 7268($t0)
        sw $t2, 7272($t0)
        sw $t2, 7276($t0)
        sw $t2, 7280($t0)
        sw $t2, 7284($t0)
        sw $t2, 7288($t0)
        sw $t2, 7292($t0)
        sw $t2, 7296($t0)
        sw $t2, 7300($t0)
        sw $t2, 7304($t0)
        sw $t2, 7308($t0)
        sw $t2, 7312($t0)
        sw $t2, 7316($t0)
        sw $t2, 7320($t0)
        sw $t2, 7324($t0)
        sw $t2, 7328($t0)
        sw $t2, 7332($t0)
        sw $t2, 7336($t0)
        sw $t2, 7340($t0)
        sw $t2, 7344($t0)
        sw $t2, 7348($t0)
        sw $t2, 7352($t0)
        sw $t2, 7356($t0)
        sw $t2, 7360($t0)
        sw $t2, 7364($t0)
        sw $t2, 7368($t0)
        sw $t2, 7372($t0)
        sw $t2, 7376($t0)
        sw $t2, 7380($t0)
        sw $t2, 7384($t0)
        sw $t2, 7388($t0)
        sw $t2, 7392($t0)
        sw $t2, 7396($t0)
        sw $t2, 7400($t0)
        sw $t2, 7404($t0)
        sw $t2, 7408($t0)
        sw $t2, 7412($t0)
        sw $t2, 7416($t0)
        sw $t2, 7420($t0)
        sw $t2, 7424($t0)
        sw $t2, 7428($t0)
        sw $t2, 7432($t0)
        sw $t2, 7436($t0)
        sw $t2, 7440($t0)
        sw $t2, 7444($t0)
        sw $t2, 7448($t0)
        sw $t2, 7452($t0)
        sw $t2, 7456($t0)
        sw $t2, 7460($t0)
        sw $t2, 7464($t0)
        sw $t2, 7468($t0)
        sw $t2, 7472($t0)
        sw $t2, 7476($t0)
        sw $t2, 7480($t0)
        sw $t2, 7484($t0)
        sw $t2, 7488($t0)
        sw $t2, 7492($t0)
        sw $t2, 7496($t0)
        sw $t2, 7500($t0)
        sw $t2, 7504($t0)
        sw $t2, 7508($t0)
        sw $t2, 7512($t0)
        sw $t2, 7516($t0)
        sw $t2, 7520($t0)
        sw $t2, 7524($t0)
        sw $t2, 7528($t0)
        sw $t2, 7532($t0)
        sw $t2, 7536($t0)
        sw $t2, 7540($t0)
        sw $t2, 7544($t0)
        sw $t2, 7548($t0)
        sw $t2, 7552($t0)
        sw $t2, 7556($t0)
        sw $t2, 7560($t0)
        sw $t2, 7564($t0)
        sw $t2, 7568($t0)
        sw $t2, 7572($t0)
        sw $t2, 7576($t0)
        sw $t2, 7580($t0)
        sw $t2, 7584($t0)
        sw $t2, 7588($t0)
        sw $t2, 7592($t0)
        sw $t2, 7596($t0)
        sw $t2, 7600($t0)
        sw $t2, 7604($t0)
        sw $t2, 7608($t0)
        sw $t2, 7612($t0)
        sw $t2, 7616($t0)
        sw $t2, 7620($t0)
        sw $t2, 7624($t0)
        sw $t2, 7628($t0)
        sw $t2, 7632($t0)
        sw $t2, 7636($t0)
        sw $t2, 7640($t0)
        sw $t2, 7644($t0)
        sw $t2, 7648($t0)
        sw $t2, 7652($t0)
        sw $t2, 7656($t0)
        sw $t2, 7660($t0)
        sw $t2, 7664($t0)
        sw $t2, 7668($t0)
        sw $t2, 7672($t0)
        sw $t2, 7676($t0)
        sw $t2, 7680($t0)
        sw $t2, 7684($t0)
        sw $t2, 7688($t0)
        sw $t2, 7692($t0)
        sw $t2, 7696($t0)
        sw $t2, 7700($t0)
        sw $t2, 7704($t0)
        sw $t2, 7708($t0)
        sw $t2, 7712($t0)
        sw $t2, 7716($t0)
        sw $t2, 7720($t0)
        sw $t2, 7724($t0)
        sw $t2, 7728($t0)
        sw $t2, 7732($t0)
        sw $t2, 7736($t0)
        sw $t2, 7740($t0)
        sw $t2, 7744($t0)
        sw $t2, 7748($t0)
        sw $t2, 7752($t0)
        sw $t2, 7756($t0)
        sw $t2, 7760($t0)
        sw $t2, 7764($t0)
        sw $t2, 7768($t0)
        sw $t2, 7772($t0)
        sw $t2, 7776($t0)
        sw $t2, 7780($t0)
        sw $t2, 7784($t0)
        sw $t2, 7788($t0)
        sw $t2, 7792($t0)
        sw $t2, 7796($t0)
        sw $t2, 7800($t0)
        sw $t2, 7804($t0)
        sw $t2, 7808($t0)
        sw $t2, 7812($t0)
        sw $t2, 7816($t0)
        sw $t2, 7820($t0)
        sw $t2, 7824($t0)
        sw $t2, 7828($t0)
        sw $t2, 7832($t0)
        sw $t2, 7836($t0)
        sw $t2, 7840($t0)
        sw $t2, 7844($t0)
        sw $t2, 7848($t0)
        sw $t2, 7852($t0)
        sw $t2, 7856($t0)
        sw $t2, 7860($t0)
        sw $t2, 7864($t0)
        sw $t2, 7868($t0)
        sw $t2, 7872($t0)
        sw $t2, 7876($t0)
        sw $t2, 7880($t0)
        sw $t2, 7884($t0)
        sw $t2, 7888($t0)
        sw $t2, 7892($t0)
        sw $t2, 7896($t0)
        sw $t2, 7900($t0)
        sw $t2, 7904($t0)
        sw $t2, 7908($t0)
        sw $t2, 7912($t0)
        sw $t2, 7916($t0)
        sw $t2, 7920($t0)
        sw $t2, 7924($t0)
        sw $t2, 7928($t0)
        sw $t2, 7932($t0)
        sw $t2, 7936($t0)
        sw $t2, 7940($t0)
        sw $t2, 7944($t0)
        sw $t2, 7948($t0)
        sw $t2, 7952($t0)
        sw $t2, 7956($t0)
        sw $t2, 7960($t0)
        sw $t2, 7964($t0)
        sw $t2, 7968($t0)
        sw $t2, 7972($t0)
        sw $t2, 7976($t0)
        sw $t2, 7980($t0)
        sw $t2, 7984($t0)
        sw $t2, 7988($t0)
        sw $t2, 7992($t0)
        sw $t2, 7996($t0)
        sw $t2, 8000($t0)
        sw $t2, 8004($t0)
        sw $t2, 8008($t0)
        sw $t2, 8012($t0)
        sw $t2, 8016($t0)
        sw $t2, 8020($t0)
        sw $t2, 8024($t0)
        sw $t2, 8028($t0)
        sw $t2, 8032($t0)
        sw $t2, 8036($t0)
        sw $t2, 8040($t0)
        sw $t2, 8044($t0)
        sw $t2, 8048($t0)
        sw $t2, 8052($t0)
        sw $t2, 8056($t0)
        sw $t2, 8060($t0)
        sw $t2, 8064($t0)
        sw $t2, 8068($t0)
        sw $t2, 8072($t0)
        sw $t2, 8076($t0)
        sw $t2, 8080($t0)
        sw $t2, 8084($t0)
        sw $t2, 8088($t0)
        sw $t2, 8092($t0)
        sw $t2, 8096($t0)
        sw $t2, 8100($t0)
        sw $t2, 8104($t0)
        sw $t2, 8108($t0)
        sw $t2, 8112($t0)
        sw $t2, 8116($t0)
        sw $t2, 8120($t0)
        sw $t2, 8124($t0)
        sw $t2, 8128($t0)
        sw $t2, 8132($t0)
        sw $t2, 8136($t0)
        sw $t2, 8140($t0)
        sw $t2, 8144($t0)
        sw $t2, 8148($t0)
        sw $t2, 8152($t0)
        sw $t2, 8156($t0)
        sw $t2, 8160($t0)
        sw $t2, 8164($t0)
        sw $t2, 8168($t0)
        sw $t2, 8172($t0)
        sw $t2, 8176($t0)
        sw $t2, 8180($t0)
        sw $t2, 8184($t0)
        sw $t2, 8188($t0)
        sw $t2, 8192($t0)
        sw $t2, 8196($t0)
        sw $t2, 8200($t0)
        sw $t2, 8204($t0)
        sw $t2, 8208($t0)
        sw $t2, 8212($t0)
        sw $t2, 8216($t0)
        sw $t2, 8220($t0)
        sw $t2, 8224($t0)
        sw $t2, 8228($t0)
        sw $t2, 8232($t0)
        sw $t2, 8236($t0)
        sw $t2, 8240($t0)
        sw $t2, 8244($t0)
        sw $t2, 8248($t0)
        sw $t2, 8252($t0)
        sw $t2, 8256($t0)
        sw $t2, 8260($t0)
        sw $t2, 8264($t0)
        sw $t2, 8268($t0)
        sw $t2, 8272($t0)
        sw $t2, 8276($t0)
        sw $t2, 8280($t0)
        sw $t2, 8284($t0)
        sw $t2, 8288($t0)
        sw $t2, 8292($t0)
        sw $t2, 8296($t0)
        sw $t2, 8300($t0)
        sw $t2, 8304($t0)
        sw $t2, 8308($t0)
        sw $t2, 8312($t0)
        sw $t2, 8316($t0)
        sw $t2, 8320($t0)
        sw $t2, 8324($t0)
        sw $t2, 8328($t0)
        sw $t2, 8332($t0)
        sw $t2, 8336($t0)
        sw $t2, 8340($t0)
        sw $t2, 8344($t0)
        sw $t2, 8348($t0)
        sw $t2, 8352($t0)
        sw $t2, 8356($t0)
        sw $t2, 8360($t0)
        sw $t2, 8364($t0)
        sw $t2, 8368($t0)
        sw $t2, 8372($t0)
        sw $t2, 8376($t0)
        sw $t2, 8380($t0)
        sw $t2, 8384($t0)
        sw $t2, 8388($t0)
        sw $t2, 8392($t0)
        sw $t2, 8396($t0)
        sw $t2, 8400($t0)
        sw $t2, 8404($t0)
        sw $t2, 8408($t0)
        sw $t2, 8412($t0)
        sw $t2, 8416($t0)
        sw $t2, 8420($t0)
        sw $t2, 8424($t0)
        sw $t2, 8428($t0)
        sw $t2, 8432($t0)
        sw $t2, 8436($t0)
        sw $t2, 8440($t0)
        sw $t2, 8444($t0)
        sw $t2, 8448($t0)
        sw $t2, 8452($t0)
        sw $t2, 8456($t0)
        sw $t2, 8460($t0)
        sw $t2, 8464($t0)
        sw $t2, 8468($t0)
        sw $t2, 8472($t0)
        sw $t2, 8476($t0)
        sw $t2, 8480($t0)
        sw $t2, 8484($t0)
        sw $t2, 8488($t0)
        sw $t2, 8492($t0)
        sw $t2, 8496($t0)
        sw $t2, 8500($t0)
        sw $t2, 8504($t0)
        sw $t2, 8508($t0)
        sw $t2, 8512($t0)
        sw $t2, 8516($t0)
        sw $t2, 8520($t0)
        sw $t2, 8524($t0)
        sw $t2, 8528($t0)
        sw $t2, 8532($t0)
        sw $t2, 8536($t0)
        sw $t2, 8540($t0)
        sw $t2, 8544($t0)
        sw $t2, 8548($t0)
        sw $t2, 8552($t0)
        sw $t2, 8556($t0)
        sw $t2, 8560($t0)
        sw $t2, 8564($t0)
        sw $t2, 8568($t0)
        sw $t2, 8572($t0)
        sw $t2, 8576($t0)
        sw $t2, 8580($t0)
        sw $t2, 8584($t0)
        sw $t2, 8588($t0)
        sw $t2, 8592($t0)
        sw $t2, 8596($t0)
        sw $t2, 8600($t0)
        sw $t2, 8604($t0)
        sw $t2, 8608($t0)
        sw $t2, 8612($t0)
        sw $t2, 8616($t0)
        sw $t2, 8620($t0)
        sw $t2, 8624($t0)
        sw $t2, 8628($t0)
        sw $t2, 8632($t0)
        sw $t2, 8636($t0)
        sw $t2, 8640($t0)
        sw $t2, 8644($t0)
        sw $t2, 8648($t0)
        sw $t2, 8652($t0)
        sw $t2, 8656($t0)
        sw $t2, 8660($t0)
        sw $t2, 8664($t0)
        sw $t2, 8668($t0)
        sw $t2, 8672($t0)
        sw $t2, 8676($t0)
        sw $t2, 8680($t0)
        sw $t2, 8684($t0)
        sw $t2, 8688($t0)
        sw $t2, 8692($t0)
        sw $t2, 8696($t0)
        sw $t2, 8700($t0)
        sw $t2, 8704($t0)
        sw $t2, 8708($t0)
        sw $t2, 8712($t0)
        sw $t2, 8716($t0)
        sw $t2, 8720($t0)
        sw $t2, 8724($t0)
        sw $t2, 8728($t0)
        sw $t2, 8732($t0)
        sw $t2, 8736($t0)
        sw $t2, 8740($t0)
        sw $t2, 8744($t0)
        sw $t2, 8748($t0)
        sw $t2, 8752($t0)
        sw $t2, 8756($t0)
        sw $t2, 8760($t0)
        sw $t2, 8764($t0)
        sw $t2, 8768($t0)
        sw $t2, 8772($t0)
        sw $t2, 8776($t0)
        sw $t2, 8780($t0)
        sw $t2, 8784($t0)
        sw $t2, 8788($t0)
        sw $t2, 8792($t0)
        sw $t2, 8796($t0)
        sw $t2, 8800($t0)
        sw $t2, 8804($t0)
        sw $t2, 8808($t0)
        sw $t2, 8812($t0)
        sw $t2, 8816($t0)
        sw $t2, 8820($t0)
        sw $t2, 8824($t0)
        sw $t2, 8828($t0)
        sw $t2, 8832($t0)
        sw $t2, 8836($t0)
        sw $t2, 8840($t0)
        sw $t2, 8844($t0)
        sw $t2, 8848($t0)
        sw $t2, 8852($t0)
        sw $t2, 8856($t0)
        sw $t2, 8860($t0)
        sw $t2, 8864($t0)
        sw $t2, 8868($t0)
        sw $t2, 8872($t0)
        sw $t2, 8876($t0)
        sw $t2, 8880($t0)
        sw $t2, 8884($t0)
        sw $t2, 8888($t0)
        sw $t2, 8892($t0)
        sw $t2, 8896($t0)
        sw $t2, 8900($t0)
        sw $t2, 8904($t0)
        sw $t2, 8908($t0)
        sw $t2, 8912($t0)
        sw $t2, 8916($t0)
        sw $t2, 8920($t0)
        sw $t2, 8924($t0)
        sw $t2, 8928($t0)
        sw $t2, 8932($t0)
        sw $t2, 8936($t0)
        sw $t2, 8940($t0)
        sw $t2, 8944($t0)
        sw $t2, 8948($t0)
        sw $t2, 8952($t0)
        sw $t2, 8956($t0)
        sw $t2, 8960($t0)
        sw $t2, 8964($t0)
        sw $t2, 8968($t0)
        sw $t2, 8972($t0)
        sw $t2, 8976($t0)
        sw $t2, 8980($t0)
        sw $t2, 8984($t0)
        sw $t2, 8988($t0)
        sw $t2, 8992($t0)
        sw $t2, 8996($t0)
        sw $t2, 9000($t0)
        sw $t2, 9004($t0)
        sw $t2, 9008($t0)
        sw $t2, 9012($t0)
        sw $t2, 9016($t0)
        sw $t2, 9020($t0)
        sw $t2, 9024($t0)
        sw $t2, 9028($t0)
        sw $t2, 9032($t0)
        sw $t2, 9036($t0)
        sw $t2, 9040($t0)
        sw $t2, 9044($t0)
        sw $t2, 9048($t0)
        sw $t2, 9052($t0)
        sw $t2, 9056($t0)
        sw $t2, 9060($t0)
        sw $t2, 9064($t0)
        sw $t2, 9068($t0)
        sw $t2, 9072($t0)
        sw $t2, 9076($t0)
        sw $t2, 9080($t0)
        sw $t2, 9084($t0)
        sw $t2, 9088($t0)
        sw $t2, 9092($t0)
        sw $t2, 9096($t0)
        sw $t2, 9100($t0)
        sw $t2, 9104($t0)
        sw $t2, 9108($t0)
        sw $t2, 9112($t0)
        sw $t2, 9116($t0)
        sw $t2, 9120($t0)
        sw $t2, 9124($t0)
        sw $t2, 9128($t0)
        sw $t2, 9132($t0)
        sw $t2, 9136($t0)
        sw $t2, 9140($t0)
        sw $t2, 9144($t0)
        sw $t2, 9148($t0)
        sw $t2, 9152($t0)
        sw $t2, 9156($t0)
        sw $t2, 9160($t0)
        sw $t2, 9164($t0)
        sw $t2, 9168($t0)
        sw $t2, 9172($t0)
        sw $t2, 9176($t0)
        sw $t2, 9180($t0)
        sw $t2, 9184($t0)
        sw $t2, 9188($t0)
        sw $t2, 9192($t0)
        sw $t2, 9196($t0)
        sw $t2, 9200($t0)
        sw $t2, 9204($t0)
        sw $t2, 9208($t0)
        sw $t2, 9212($t0)
        sw $t2, 9216($t0)
        sw $t2, 9220($t0)
        sw $t2, 9224($t0)
        sw $t2, 9228($t0)
        sw $t2, 9232($t0)
        sw $t2, 9236($t0)
        sw $t2, 9240($t0)
        sw $t2, 9244($t0)
        sw $t2, 9248($t0)
        sw $t2, 9252($t0)
        sw $t2, 9256($t0)
        sw $t2, 9260($t0)
        sw $t2, 9264($t0)
        sw $t2, 9268($t0)
        sw $t2, 9272($t0)
        sw $t2, 9276($t0)
        sw $t2, 9280($t0)
        sw $t2, 9284($t0)
        sw $t2, 9288($t0)
        sw $t2, 9292($t0)
        sw $t2, 9296($t0)
        sw $t2, 9300($t0)
        sw $t2, 9304($t0)
        sw $t2, 9308($t0)
        sw $t2, 9312($t0)
        sw $t2, 9316($t0)
        sw $t2, 9320($t0)
        sw $t2, 9324($t0)
        sw $t2, 9328($t0)
        sw $t2, 9332($t0)
        sw $t2, 9336($t0)
        sw $t2, 9340($t0)
        sw $t2, 9344($t0)
        sw $t2, 9348($t0)
        sw $t2, 9352($t0)
        sw $t2, 9356($t0)
        sw $t2, 9360($t0)
        sw $t6, 9364($t0)
        sw $t6, 9368($t0)
        sw $t6, 9372($t0)
        sw $t2, 9376($t0)
        sw $t2, 9380($t0)
        sw $t2, 9384($t0)
        sw $t2, 9388($t0)
        sw $t2, 9392($t0)
        sw $t2, 9396($t0)
        sw $t2, 9400($t0)
        sw $t2, 9404($t0)
        sw $t2, 9408($t0)
        sw $t2, 9412($t0)
        sw $t2, 9416($t0)
        sw $t2, 9420($t0)
        sw $t2, 9424($t0)
        sw $t2, 9428($t0)
        sw $t2, 9432($t0)
        sw $t2, 9436($t0)
        sw $t2, 9440($t0)
        sw $t2, 9444($t0)
        sw $t2, 9448($t0)
        sw $t2, 9452($t0)
        sw $t2, 9456($t0)
        sw $t2, 9460($t0)
        sw $t2, 9464($t0)
        sw $t2, 9468($t0)
        sw $t2, 9472($t0)
        sw $t2, 9476($t0)
        sw $t2, 9480($t0)
        sw $t2, 9484($t0)
        sw $t2, 9488($t0)
        sw $t2, 9492($t0)
        sw $t2, 9496($t0)
        sw $t2, 9500($t0)
        sw $t2, 9504($t0)
        sw $t2, 9508($t0)
        sw $t2, 9512($t0)
        sw $t2, 9516($t0)
        sw $t2, 9520($t0)
        sw $t2, 9524($t0)
        sw $t2, 9528($t0)
        sw $t2, 9532($t0)
        sw $t2, 9536($t0)
        sw $t2, 9540($t0)
        sw $t2, 9544($t0)
        sw $t2, 9548($t0)
        sw $t2, 9552($t0)
        sw $t2, 9556($t0)
        sw $t2, 9560($t0)
        sw $t2, 9564($t0)
        sw $t2, 9568($t0)
        sw $t2, 9572($t0)
        sw $t2, 9576($t0)
        sw $t2, 9580($t0)
        sw $t2, 9584($t0)
        sw $t2, 9588($t0)
        sw $t2, 9592($t0)
        sw $t2, 9596($t0)
        sw $t2, 9600($t0)
        sw $t2, 9604($t0)
        sw $t2, 9608($t0)
        sw $t2, 9612($t0)
        sw $t6, 9616($t0)
        sw $t5, 9620($t0)
        sw $t5, 9624($t0)
        sw $t5, 9628($t0)
        sw $t6, 9632($t0)
        sw $t2, 9636($t0)
        sw $t2, 9640($t0)
        sw $t2, 9644($t0)
        sw $t2, 9648($t0)
        sw $t2, 9652($t0)
        sw $t2, 9656($t0)
        sw $t2, 9660($t0)
        sw $t2, 9664($t0)
        sw $t2, 9668($t0)
        sw $t2, 9672($t0)
        sw $t2, 9676($t0)
        sw $t2, 9680($t0)
        sw $t2, 9684($t0)
        sw $t2, 9688($t0)
        sw $t2, 9692($t0)
        sw $t2, 9696($t0)
        sw $t2, 9700($t0)
        sw $t2, 9704($t0)
        sw $t2, 9708($t0)
        sw $t2, 9712($t0)
        sw $t2, 9716($t0)
        sw $t2, 9720($t0)
        sw $t2, 9724($t0)
        sw $t2, 9728($t0)
        sw $t2, 9732($t0)
        sw $t2, 9736($t0)
        sw $t2, 9740($t0)
        sw $t2, 9744($t0)
        sw $t2, 9748($t0)
        sw $t2, 9752($t0)
        sw $t2, 9756($t0)
        sw $t2, 9760($t0)
        sw $t2, 9764($t0)
        sw $t2, 9768($t0)
        sw $t2, 9772($t0)
        sw $t2, 9776($t0)
        sw $t2, 9780($t0)
        sw $t2, 9784($t0)
        sw $t2, 9788($t0)
        sw $t2, 9792($t0)
        sw $t2, 9796($t0)
        sw $t2, 9800($t0)
        sw $t2, 9804($t0)
        sw $t2, 9808($t0)
        sw $t2, 9812($t0)
        sw $t2, 9816($t0)
        sw $t2, 9820($t0)
        sw $t2, 9824($t0)
        sw $t2, 9828($t0)
        sw $t2, 9832($t0)
        sw $t2, 9836($t0)
        sw $t2, 9840($t0)
        sw $t2, 9844($t0)
        sw $t2, 9848($t0)
        sw $t2, 9852($t0)
        sw $t2, 9856($t0)
        sw $t2, 9860($t0)
        sw $t2, 9864($t0)
        sw $t6, 9868($t0)
        sw $t5, 9872($t0)
        sw $t5, 9876($t0)
        sw $t3, 9880($t0)
        sw $t4, 9884($t0)
        sw $t5, 9888($t0)
        sw $t6, 9892($t0)
        sw $t2, 9896($t0)
        sw $t2, 9900($t0)
        sw $t2, 9904($t0)
        sw $t2, 9908($t0)
        sw $t2, 9912($t0)
        sw $t2, 9916($t0)
        sw $t2, 9920($t0)
        sw $t2, 9924($t0)
        sw $t2, 9928($t0)
        sw $t2, 9932($t0)
        sw $t2, 9936($t0)
        sw $t2, 9940($t0)
        sw $t2, 9944($t0)
        sw $t2, 9948($t0)
        sw $t2, 9952($t0)
        sw $t2, 9956($t0)
        sw $t2, 9960($t0)
        sw $t2, 9964($t0)
        sw $t2, 9968($t0)
        sw $t2, 9972($t0)
        sw $t2, 9976($t0)
        sw $t2, 9980($t0)
        sw $t2, 9984($t0)
        sw $t2, 9988($t0)
        sw $t2, 9992($t0)
        sw $t2, 9996($t0)
        sw $t2, 10000($t0)
        sw $t2, 10004($t0)
        sw $t2, 10008($t0)
        sw $t2, 10012($t0)
        sw $t2, 10016($t0)
        sw $t2, 10020($t0)
        sw $t2, 10024($t0)
        sw $t2, 10028($t0)
        sw $t2, 10032($t0)
        sw $t2, 10036($t0)
        sw $t2, 10040($t0)
        sw $t2, 10044($t0)
        sw $t2, 10048($t0)
        sw $t2, 10052($t0)
        sw $t2, 10056($t0)
        sw $t2, 10060($t0)
        sw $t2, 10064($t0)
        sw $t2, 10068($t0)
        sw $t2, 10072($t0)
        sw $t2, 10076($t0)
        sw $t2, 10080($t0)
        sw $t2, 10084($t0)
        sw $t2, 10088($t0)
        sw $t2, 10092($t0)
        sw $t2, 10096($t0)
        sw $t2, 10100($t0)
        sw $t2, 10104($t0)
        sw $t2, 10108($t0)
        sw $t2, 10112($t0)
        sw $t2, 10116($t0)
        sw $t2, 10120($t0)
        sw $t6, 10124($t0)
        sw $t5, 10128($t0)
        sw $t3, 10132($t0)
        sw $t5, 10136($t0)
        sw $t4, 10140($t0)
        sw $t5, 10144($t0)
        sw $t6, 10148($t0)
        sw $t2, 10152($t0)
        sw $t2, 10156($t0)
        sw $t2, 10160($t0)
        sw $t2, 10164($t0)
        sw $t2, 10168($t0)
        sw $t2, 10172($t0)
        sw $t2, 10176($t0)
        sw $t2, 10180($t0)
        sw $t2, 10184($t0)
        sw $t2, 10188($t0)
        sw $t2, 10192($t0)
        sw $t2, 10196($t0)
        sw $t2, 10200($t0)
        sw $t2, 10204($t0)
        sw $t2, 10208($t0)
        sw $t2, 10212($t0)
        sw $t2, 10216($t0)
        sw $t2, 10220($t0)
        sw $t2, 10224($t0)
        sw $t2, 10228($t0)
        sw $t2, 10232($t0)
        sw $t2, 10236($t0)
        sw $t2, 10240($t0)
        sw $t2, 10244($t0)
        sw $t2, 10248($t0)
        sw $t2, 10252($t0)
        sw $t2, 10256($t0)
        sw $t2, 10260($t0)
        sw $t2, 10264($t0)
        sw $t2, 10268($t0)
        sw $t2, 10272($t0)
        sw $t2, 10276($t0)
        sw $t2, 10280($t0)
        sw $t2, 10284($t0)
        sw $t2, 10288($t0)
        sw $t2, 10292($t0)
        sw $t2, 10296($t0)
        sw $t2, 10300($t0)
        sw $t2, 10304($t0)
        sw $t2, 10308($t0)
        sw $t2, 10312($t0)
        sw $t2, 10316($t0)
        sw $t2, 10320($t0)
        sw $t2, 10324($t0)
        sw $t2, 10328($t0)
        sw $t2, 10332($t0)
        sw $t2, 10336($t0)
        sw $t2, 10340($t0)
        sw $t2, 10344($t0)
        sw $t2, 10348($t0)
        sw $t2, 10352($t0)
        sw $t2, 10356($t0)
        sw $t2, 10360($t0)
        sw $t2, 10364($t0)
        sw $t2, 10368($t0)
        sw $t2, 10372($t0)
        sw $t2, 10376($t0)
        sw $t6, 10380($t0)
        sw $t5, 10384($t0)
        sw $t4, 10388($t0)
        sw $t4, 10392($t0)
        sw $t4, 10396($t0)
        sw $t5, 10400($t0)
        sw $t6, 10404($t0)
        sw $t2, 10408($t0)
        sw $t2, 10412($t0)
        sw $t2, 10416($t0)
        sw $t2, 10420($t0)
        sw $t2, 10424($t0)
        sw $t2, 10428($t0)
        sw $t2, 10432($t0)
        sw $t2, 10436($t0)
        sw $t2, 10440($t0)
        sw $t2, 10444($t0)
        sw $t2, 10448($t0)
        sw $t2, 10452($t0)
        sw $t2, 10456($t0)
        sw $t2, 10460($t0)
        sw $t2, 10464($t0)
        sw $t2, 10468($t0)
        sw $t2, 10472($t0)
        sw $t2, 10476($t0)
        sw $t2, 10480($t0)
        sw $t2, 10484($t0)
        sw $t2, 10488($t0)
        sw $t2, 10492($t0)
        sw $t2, 10496($t0)
        sw $t2, 10500($t0)
        sw $t2, 10504($t0)
        sw $t2, 10508($t0)
        sw $t2, 10512($t0)
        sw $t2, 10516($t0)
        sw $t2, 10520($t0)
        sw $t2, 10524($t0)
        sw $t2, 10528($t0)
        sw $t2, 10532($t0)
        sw $t2, 10536($t0)
        sw $t2, 10540($t0)
        sw $t2, 10544($t0)
        sw $t2, 10548($t0)
        sw $t2, 10552($t0)
        sw $t2, 10556($t0)
        sw $t2, 10560($t0)
        sw $t2, 10564($t0)
        sw $t2, 10568($t0)
        sw $t2, 10572($t0)
        sw $t2, 10576($t0)
        sw $t2, 10580($t0)
        sw $t2, 10584($t0)
        sw $t2, 10588($t0)
        sw $t2, 10592($t0)
        sw $t2, 10596($t0)
        sw $t2, 10600($t0)
        sw $t2, 10604($t0)
        sw $t2, 10608($t0)
        sw $t2, 10612($t0)
        sw $t2, 10616($t0)
        sw $t2, 10620($t0)
        sw $t2, 10624($t0)
        sw $t2, 10628($t0)
        sw $t2, 10632($t0)
        sw $t2, 10636($t0)
        sw $t6, 10640($t0)
        sw $t5, 10644($t0)
        sw $t5, 10648($t0)
        sw $t5, 10652($t0)
        sw $t6, 10656($t0)
        sw $t2, 10660($t0)
        sw $t2, 10664($t0)
        sw $t2, 10668($t0)
        sw $t2, 10672($t0)
        sw $t2, 10676($t0)
        sw $t2, 10680($t0)
        sw $t2, 10684($t0)
        sw $t2, 10688($t0)
        sw $t2, 10692($t0)
        sw $t2, 10696($t0)
        sw $t2, 10700($t0)
        sw $t2, 10704($t0)
        sw $t2, 10708($t0)
        sw $t2, 10712($t0)
        sw $t2, 10716($t0)
        sw $t2, 10720($t0)
        sw $t2, 10724($t0)
        sw $t2, 10728($t0)
        sw $t2, 10732($t0)
        sw $t2, 10736($t0)
        sw $t2, 10740($t0)
        sw $t2, 10744($t0)
        sw $t2, 10748($t0)
        sw $t2, 10752($t0)
        sw $t2, 10756($t0)
        sw $t2, 10760($t0)
        sw $t2, 10764($t0)
        sw $t2, 10768($t0)
        sw $t2, 10772($t0)
        sw $t2, 10776($t0)
        sw $t2, 10780($t0)
        sw $t2, 10784($t0)
        sw $t2, 10788($t0)
        sw $t2, 10792($t0)
        sw $t2, 10796($t0)
        sw $t2, 10800($t0)
        sw $t2, 10804($t0)
        sw $t2, 10808($t0)
        sw $t2, 10812($t0)
        sw $t2, 10816($t0)
        sw $t2, 10820($t0)
        sw $t2, 10824($t0)
        sw $t2, 10828($t0)
        sw $t2, 10832($t0)
        sw $t2, 10836($t0)
        sw $t2, 10840($t0)
        sw $t2, 10844($t0)
        sw $t2, 10848($t0)
        sw $t2, 10852($t0)
        sw $t2, 10856($t0)
        sw $t2, 10860($t0)
        sw $t2, 10864($t0)
        sw $t2, 10868($t0)
        sw $t2, 10872($t0)
        sw $t2, 10876($t0)
        sw $t2, 10880($t0)
        sw $t2, 10884($t0)
        sw $t2, 10888($t0)
        sw $t2, 10892($t0)
        sw $t2, 10896($t0)
        sw $t6, 10900($t0)
        sw $t6, 10904($t0)
        sw $t6, 10908($t0)
        sw $t2, 10912($t0)
        sw $t2, 10916($t0)
        sw $t2, 10920($t0)
        sw $t2, 10924($t0)
        sw $t2, 10928($t0)
        sw $t2, 10932($t0)
        sw $t2, 10936($t0)
        sw $t2, 10940($t0)
        sw $t2, 10944($t0)
        sw $t2, 10948($t0)
        sw $t2, 10952($t0)
        sw $t2, 10956($t0)
        sw $t2, 10960($t0)
        sw $t2, 10964($t0)
        sw $t2, 10968($t0)
        sw $t2, 10972($t0)
        sw $t2, 10976($t0)
        sw $t2, 10980($t0)
        sw $t2, 10984($t0)
        sw $t2, 10988($t0)
        sw $t2, 10992($t0)
        sw $t2, 10996($t0)
        sw $t2, 11000($t0)
        sw $t2, 11004($t0)
        sw $t2, 11008($t0)
        sw $t2, 11012($t0)
        sw $t2, 11016($t0)
        sw $t2, 11020($t0)
        sw $t2, 11024($t0)
        sw $t2, 11028($t0)
        sw $t2, 11032($t0)
        sw $t2, 11036($t0)
        sw $t2, 11040($t0)
        sw $t2, 11044($t0)
        sw $t2, 11048($t0)
        sw $t2, 11052($t0)
        sw $t2, 11056($t0)
        sw $t2, 11060($t0)
        sw $t2, 11064($t0)
        sw $t2, 11068($t0)
        sw $t2, 11072($t0)
        sw $t2, 11076($t0)
        sw $t2, 11080($t0)
        sw $t2, 11084($t0)
        sw $t2, 11088($t0)
        sw $t2, 11092($t0)
        sw $t2, 11096($t0)
        sw $t2, 11100($t0)
        sw $t2, 11104($t0)
        sw $t2, 11108($t0)
        sw $t2, 11112($t0)
        sw $t2, 11116($t0)
        sw $t2, 11120($t0)
        sw $t2, 11124($t0)
        sw $t2, 11128($t0)
        sw $t2, 11132($t0)
        sw $t2, 11136($t0)
        sw $t2, 11140($t0)
        sw $t2, 11144($t0)
        sw $t2, 11148($t0)
        sw $t2, 11152($t0)
        sw $t2, 11156($t0)
        sw $t2, 11160($t0)
        sw $t2, 11164($t0)
        sw $t2, 11168($t0)
        sw $t2, 11172($t0)
        sw $t2, 11176($t0)
        sw $t2, 11180($t0)
        sw $t2, 11184($t0)
        sw $t2, 11188($t0)
        sw $t2, 11192($t0)
        sw $t2, 11196($t0)
        sw $t2, 11200($t0)
        sw $t2, 11204($t0)
        sw $t2, 11208($t0)
        sw $t2, 11212($t0)
        sw $t2, 11216($t0)
        sw $t2, 11220($t0)
        sw $t2, 11224($t0)
        sw $t2, 11228($t0)
        sw $t2, 11232($t0)
        sw $t2, 11236($t0)
        sw $t2, 11240($t0)
        sw $t2, 11244($t0)
        sw $t2, 11248($t0)
        sw $t2, 11252($t0)
        sw $t2, 11256($t0)
        sw $t2, 11260($t0)
        sw $t2, 11264($t0)
        sw $t2, 11268($t0)
        sw $t2, 11272($t0)
        sw $t2, 11276($t0)
        sw $t2, 11280($t0)
        sw $t2, 11284($t0)
        sw $t2, 11288($t0)
        sw $t2, 11292($t0)
        sw $t2, 11296($t0)
        sw $t2, 11300($t0)
        sw $t2, 11304($t0)
        sw $t2, 11308($t0)
        sw $t2, 11312($t0)
        sw $t2, 11316($t0)
        sw $t2, 11320($t0)
        sw $t2, 11324($t0)
        sw $t2, 11328($t0)
        sw $t2, 11332($t0)
        sw $t2, 11336($t0)
        sw $t2, 11340($t0)
        sw $t2, 11344($t0)
        sw $t2, 11348($t0)
        sw $t2, 11352($t0)
        sw $t2, 11356($t0)
        sw $t2, 11360($t0)
        sw $t2, 11364($t0)
        sw $t2, 11368($t0)
        sw $t2, 11372($t0)
        sw $t2, 11376($t0)
        sw $t2, 11380($t0)
        sw $t2, 11384($t0)
        sw $t2, 11388($t0)
        sw $t2, 11392($t0)
        sw $t2, 11396($t0)
        sw $t2, 11400($t0)
        sw $t2, 11404($t0)
        sw $t2, 11408($t0)
        sw $t2, 11412($t0)
        sw $t2, 11416($t0)
        sw $t2, 11420($t0)
        sw $t2, 11424($t0)
        sw $t2, 11428($t0)
        sw $t2, 11432($t0)
        sw $t2, 11436($t0)
        sw $t2, 11440($t0)
        sw $t2, 11444($t0)
        sw $t2, 11448($t0)
        sw $t2, 11452($t0)
        sw $t2, 11456($t0)
        sw $t2, 11460($t0)
        sw $t2, 11464($t0)
        sw $t2, 11468($t0)
        sw $t2, 11472($t0)
        sw $t2, 11476($t0)
        sw $t2, 11480($t0)
        sw $t2, 11484($t0)
        sw $t2, 11488($t0)
        sw $t2, 11492($t0)
        sw $t2, 11496($t0)
        sw $t2, 11500($t0)
        sw $t2, 11504($t0)
        sw $t2, 11508($t0)
        sw $t2, 11512($t0)
        sw $t2, 11516($t0)
        sw $t2, 11520($t0)
        sw $t2, 11524($t0)
        sw $t2, 11528($t0)
        sw $t2, 11532($t0)
        sw $t2, 11536($t0)
        sw $t2, 11540($t0)
        sw $t2, 11544($t0)
        sw $t2, 11548($t0)
        sw $t2, 11552($t0)
        sw $t2, 11556($t0)
        sw $t2, 11560($t0)
        sw $t2, 11564($t0)
        sw $t2, 11568($t0)
        sw $t2, 11572($t0)
        sw $t2, 11576($t0)
        sw $t2, 11580($t0)
        sw $t2, 11584($t0)
        sw $t2, 11588($t0)
        sw $t2, 11592($t0)
        sw $t2, 11596($t0)
        sw $t2, 11600($t0)
        sw $t2, 11604($t0)
        sw $t2, 11608($t0)
        sw $t2, 11612($t0)
        sw $t2, 11616($t0)
        sw $t2, 11620($t0)
        sw $t2, 11624($t0)
        sw $t2, 11628($t0)
        sw $t2, 11632($t0)
        sw $t2, 11636($t0)
        sw $t2, 11640($t0)
        sw $t2, 11644($t0)
        sw $t2, 11648($t0)
        sw $t2, 11652($t0)
        sw $t2, 11656($t0)
        sw $t2, 11660($t0)
        sw $t2, 11664($t0)
        sw $t2, 11668($t0)
        sw $t2, 11672($t0)
        sw $t2, 11676($t0)
        sw $t2, 11680($t0)
        sw $t2, 11684($t0)
        sw $t2, 11688($t0)
        sw $t2, 11692($t0)
        sw $t2, 11696($t0)
        sw $t2, 11700($t0)
        sw $t2, 11704($t0)
        sw $t2, 11708($t0)
        sw $t2, 11712($t0)
        sw $t2, 11716($t0)
        sw $t2, 11720($t0)
        sw $t2, 11724($t0)
        sw $t2, 11728($t0)
        sw $t2, 11732($t0)
        sw $t2, 11736($t0)
        sw $t2, 11740($t0)
        sw $t2, 11744($t0)
        sw $t2, 11748($t0)
        sw $t2, 11752($t0)
        sw $t2, 11756($t0)
        sw $t2, 11760($t0)
        sw $t2, 11764($t0)
        sw $t2, 11768($t0)
        sw $t2, 11772($t0)
        sw $t2, 11776($t0)
        sw $t2, 11780($t0)
        sw $t2, 11784($t0)
        sw $t2, 11788($t0)
        sw $t2, 11792($t0)
        sw $t2, 11796($t0)
        sw $t2, 11800($t0)
        sw $t2, 11804($t0)
        sw $t2, 11808($t0)
        sw $t2, 11812($t0)
        sw $t2, 11816($t0)
        sw $t2, 11820($t0)
        sw $t2, 11824($t0)
        sw $t2, 11828($t0)
        sw $t2, 11832($t0)
        sw $t2, 11836($t0)
        sw $t2, 11840($t0)
        sw $t2, 11844($t0)
        sw $t2, 11848($t0)
        sw $t2, 11852($t0)
        sw $t2, 11856($t0)
        sw $t2, 11860($t0)
        sw $t2, 11864($t0)
        sw $t2, 11868($t0)
        sw $t2, 11872($t0)
        sw $t2, 11876($t0)
        sw $t2, 11880($t0)
        sw $t2, 11884($t0)
        sw $t2, 11888($t0)
        sw $t2, 11892($t0)
        sw $t2, 11896($t0)
        sw $t2, 11900($t0)
        sw $t2, 11904($t0)
        sw $t2, 11908($t0)
        sw $t2, 11912($t0)
        sw $t2, 11916($t0)
        sw $t2, 11920($t0)
        sw $t2, 11924($t0)
        sw $t2, 11928($t0)
        sw $t2, 11932($t0)
        sw $t2, 11936($t0)
        sw $t2, 11940($t0)
        sw $t2, 11944($t0)
        sw $t2, 11948($t0)
        sw $t2, 11952($t0)
        sw $t2, 11956($t0)
        sw $t2, 11960($t0)
        sw $t2, 11964($t0)
        sw $t2, 11968($t0)
        sw $t2, 11972($t0)
        sw $t2, 11976($t0)
        sw $t2, 11980($t0)
        sw $t2, 11984($t0)
        sw $t2, 11988($t0)
        sw $t2, 11992($t0)
        sw $t2, 11996($t0)
        sw $t2, 12000($t0)
        sw $t2, 12004($t0)
        sw $t2, 12008($t0)
        sw $t2, 12012($t0)
        sw $t2, 12016($t0)
        sw $t2, 12020($t0)
        sw $t2, 12024($t0)
        sw $t2, 12028($t0)
        sw $t2, 12032($t0)
        sw $t2, 12036($t0)
        sw $t2, 12040($t0)
        sw $t2, 12044($t0)
        sw $t2, 12048($t0)
        sw $t2, 12052($t0)
        sw $t2, 12056($t0)
        sw $t2, 12060($t0)
        sw $t2, 12064($t0)
        sw $t2, 12068($t0)
        sw $t2, 12072($t0)
        sw $t2, 12076($t0)
        sw $t2, 12080($t0)
        sw $t2, 12084($t0)
        sw $t2, 12088($t0)
        sw $t2, 12092($t0)
        sw $t2, 12096($t0)
        sw $t2, 12100($t0)
        sw $t2, 12104($t0)
        sw $t2, 12108($t0)
        sw $t2, 12112($t0)
        sw $t2, 12116($t0)
        sw $t2, 12120($t0)
        sw $t2, 12124($t0)
        sw $t2, 12128($t0)
        sw $t2, 12132($t0)
        sw $t2, 12136($t0)
        sw $t2, 12140($t0)
        sw $t2, 12144($t0)
        sw $t2, 12148($t0)
        sw $t2, 12152($t0)
        sw $t2, 12156($t0)
        sw $t2, 12160($t0)
        sw $t2, 12164($t0)
        sw $t2, 12168($t0)
        sw $t2, 12172($t0)
        sw $t2, 12176($t0)
        sw $t2, 12180($t0)
        sw $t2, 12184($t0)
        sw $t2, 12188($t0)
        sw $t2, 12192($t0)
        sw $t2, 12196($t0)
        sw $t2, 12200($t0)
        sw $t2, 12204($t0)
        sw $t2, 12208($t0)
        sw $t2, 12212($t0)
        sw $t2, 12216($t0)
        sw $t2, 12220($t0)
        sw $t2, 12224($t0)
        sw $t2, 12228($t0)
        sw $t2, 12232($t0)
        sw $t2, 12236($t0)
        sw $t2, 12240($t0)
        sw $t2, 12244($t0)
        sw $t2, 12248($t0)
        sw $t2, 12252($t0)
        sw $t2, 12256($t0)
        sw $t2, 12260($t0)
        sw $t2, 12264($t0)
        sw $t2, 12268($t0)
        sw $t2, 12272($t0)
        sw $t2, 12276($t0)
        sw $t2, 12280($t0)
        sw $t2, 12284($t0)
        sw $t2, 12288($t0)
        sw $t2, 12292($t0)
        sw $t2, 12296($t0)
        sw $t2, 12300($t0)
        sw $t2, 12304($t0)
        sw $t2, 12308($t0)
        sw $t2, 12312($t0)
        sw $t2, 12316($t0)
        sw $t2, 12320($t0)
        sw $t2, 12324($t0)
        sw $t2, 12328($t0)
        sw $t2, 12332($t0)
        sw $t2, 12336($t0)
        sw $t2, 12340($t0)
        sw $t2, 12344($t0)
        sw $t2, 12348($t0)
        sw $t2, 12352($t0)
        sw $t2, 12356($t0)
        sw $t2, 12360($t0)
        sw $t2, 12364($t0)
        sw $t2, 12368($t0)
        sw $t2, 12372($t0)
        sw $t2, 12376($t0)
        sw $t2, 12380($t0)
        sw $t2, 12384($t0)
        sw $t2, 12388($t0)
        sw $t2, 12392($t0)
        sw $t2, 12396($t0)
        sw $t2, 12400($t0)
        sw $t2, 12404($t0)
        sw $t2, 12408($t0)
        sw $t2, 12412($t0)
        sw $t2, 12416($t0)
        sw $t2, 12420($t0)
        sw $t2, 12424($t0)
        sw $t2, 12428($t0)
        sw $t2, 12432($t0)
        sw $t2, 12436($t0)
        sw $t2, 12440($t0)
        sw $t2, 12444($t0)
        sw $t2, 12448($t0)
        sw $t2, 12452($t0)
        sw $t2, 12456($t0)
        sw $t2, 12460($t0)
        sw $t2, 12464($t0)
        sw $t2, 12468($t0)
        sw $t2, 12472($t0)
        sw $t2, 12476($t0)
        sw $t2, 12480($t0)
        sw $t2, 12484($t0)
        sw $t2, 12488($t0)
        sw $t2, 12492($t0)
        sw $t2, 12496($t0)
        sw $t2, 12500($t0)
        sw $t2, 12504($t0)
        sw $t2, 12508($t0)
        sw $t2, 12512($t0)
        sw $t2, 12516($t0)
        sw $t2, 12520($t0)
        sw $t2, 12524($t0)
        sw $t2, 12528($t0)
        sw $t2, 12532($t0)
        sw $t2, 12536($t0)
        sw $t2, 12540($t0)
        sw $t2, 12544($t0)
        sw $t2, 12548($t0)
        sw $t2, 12552($t0)
        sw $t2, 12556($t0)
        sw $t2, 12560($t0)
        sw $t2, 12564($t0)
        sw $t2, 12568($t0)
        sw $t2, 12572($t0)
        sw $t2, 12576($t0)
        sw $t2, 12580($t0)
        sw $t2, 12584($t0)
        sw $t2, 12588($t0)
        sw $t2, 12592($t0)
        sw $t2, 12596($t0)
        sw $t2, 12600($t0)
        sw $t2, 12604($t0)
        sw $t2, 12608($t0)
        sw $t2, 12612($t0)
        sw $t2, 12616($t0)
        sw $t2, 12620($t0)
        sw $t2, 12624($t0)
        sw $t2, 12628($t0)
        sw $t2, 12632($t0)
        sw $t2, 12636($t0)
        sw $t2, 12640($t0)
        sw $t2, 12644($t0)
        sw $t2, 12648($t0)
        sw $t2, 12652($t0)
        sw $t2, 12656($t0)
        sw $t2, 12660($t0)
        sw $t2, 12664($t0)
        sw $t2, 12668($t0)
        sw $t2, 12672($t0)
        sw $t2, 12676($t0)
        sw $t2, 12680($t0)
        sw $t2, 12684($t0)
        sw $t2, 12688($t0)
        sw $t2, 12692($t0)
        sw $t2, 12696($t0)
        sw $t2, 12700($t0)
        sw $t2, 12704($t0)
        sw $t2, 12708($t0)
        sw $t2, 12712($t0)
        sw $t2, 12716($t0)
        sw $t2, 12720($t0)
        sw $t2, 12724($t0)
        sw $t2, 12728($t0)
        sw $t2, 12732($t0)
        sw $t2, 12736($t0)
        sw $t2, 12740($t0)
        sw $t2, 12744($t0)
        sw $t2, 12748($t0)
        sw $t2, 12752($t0)
        sw $t2, 12756($t0)
        sw $t2, 12760($t0)
        sw $t2, 12764($t0)
        sw $t2, 12768($t0)
        sw $t2, 12772($t0)
        sw $t2, 12776($t0)
        sw $t2, 12780($t0)
        sw $t2, 12784($t0)
        sw $t2, 12788($t0)
        sw $t2, 12792($t0)
        sw $t2, 12796($t0)
        sw $t2, 12800($t0)
        sw $t2, 12804($t0)
        sw $t2, 12808($t0)
        sw $t2, 12812($t0)
        sw $t2, 12816($t0)
        sw $t2, 12820($t0)
        sw $t2, 12824($t0)
        sw $t2, 12828($t0)
        sw $t2, 12832($t0)
        sw $t2, 12836($t0)
        sw $t2, 12840($t0)
        sw $t2, 12844($t0)
        sw $t2, 12848($t0)
        sw $t2, 12852($t0)
        sw $t2, 12856($t0)
        sw $t2, 12860($t0)
        sw $t2, 12864($t0)
        sw $t2, 12868($t0)
        sw $t2, 12872($t0)
        sw $t2, 12876($t0)
        sw $t2, 12880($t0)
        sw $t2, 12884($t0)
        sw $t2, 12888($t0)
        sw $t2, 12892($t0)
        sw $t2, 12896($t0)
        sw $t2, 12900($t0)
        sw $t2, 12904($t0)
        sw $t2, 12908($t0)
        sw $t2, 12912($t0)
        sw $t2, 12916($t0)
        sw $t2, 12920($t0)
        sw $t2, 12924($t0)
        sw $t2, 12928($t0)
        sw $t2, 12932($t0)
        sw $t2, 12936($t0)
        sw $t2, 12940($t0)
        sw $t2, 12944($t0)
        sw $t2, 12948($t0)
        sw $t2, 12952($t0)
        sw $t2, 12956($t0)
        sw $t2, 12960($t0)
        sw $t2, 12964($t0)
        sw $t2, 12968($t0)
        sw $t2, 12972($t0)
        sw $t2, 12976($t0)
        sw $t2, 12980($t0)
        sw $t2, 12984($t0)
        sw $t2, 12988($t0)
        sw $t2, 12992($t0)
        sw $t2, 12996($t0)
        sw $t2, 13000($t0)
        sw $t2, 13004($t0)
        sw $t2, 13008($t0)
        sw $t2, 13012($t0)
        sw $t2, 13016($t0)
        sw $t2, 13020($t0)
        sw $t2, 13024($t0)
        sw $t2, 13028($t0)
        sw $t2, 13032($t0)
        sw $t2, 13036($t0)
        sw $t2, 13040($t0)
        sw $t2, 13044($t0)
        sw $t2, 13048($t0)
        sw $t2, 13052($t0)
        sw $t2, 13056($t0)
        sw $t2, 13060($t0)
        sw $t2, 13064($t0)
        sw $t2, 13068($t0)
        sw $t2, 13072($t0)
        sw $t2, 13076($t0)
        sw $t2, 13080($t0)
        sw $t2, 13084($t0)
        sw $t2, 13088($t0)
        sw $t2, 13092($t0)
        sw $t2, 13096($t0)
        sw $t2, 13100($t0)
        sw $t2, 13104($t0)
        sw $t2, 13108($t0)
        sw $t2, 13112($t0)
        sw $t2, 13116($t0)
        sw $t2, 13120($t0)
        sw $t2, 13124($t0)
        sw $t2, 13128($t0)
        sw $t2, 13132($t0)
        sw $t2, 13136($t0)
        sw $t2, 13140($t0)
        sw $t2, 13144($t0)
        sw $t2, 13148($t0)
        sw $t2, 13152($t0)
        sw $t2, 13156($t0)
        sw $t2, 13160($t0)
        sw $t2, 13164($t0)
        sw $t2, 13168($t0)
        sw $t2, 13172($t0)
        sw $t2, 13176($t0)
        sw $t2, 13180($t0)
        sw $t2, 13184($t0)
        sw $t2, 13188($t0)
        sw $t2, 13192($t0)
        sw $t2, 13196($t0)
        sw $t2, 13200($t0)
        sw $t2, 13204($t0)
        sw $t2, 13208($t0)
        sw $t2, 13212($t0)
        sw $t2, 13216($t0)
        sw $t2, 13220($t0)
        sw $t2, 13224($t0)
        sw $t2, 13228($t0)
        sw $t2, 13232($t0)
        sw $t2, 13236($t0)
        sw $t2, 13240($t0)
        sw $t2, 13244($t0)
        sw $t2, 13248($t0)
        sw $t2, 13252($t0)
        sw $t2, 13256($t0)
        sw $t2, 13260($t0)
        sw $t2, 13264($t0)
        sw $t2, 13268($t0)
        sw $t2, 13272($t0)
        sw $t2, 13276($t0)
        sw $t2, 13280($t0)
        sw $t2, 13284($t0)
        sw $t2, 13288($t0)
        sw $t2, 13292($t0)
        sw $t2, 13296($t0)
        sw $t2, 13300($t0)
        sw $t2, 13304($t0)
        sw $t2, 13308($t0)
        sw $t2, 13312($t0)
        sw $t2, 13316($t0)
        sw $t2, 13320($t0)
        sw $t2, 13324($t0)
        sw $t2, 13328($t0)
        sw $t2, 13332($t0)
        sw $t2, 13336($t0)
        sw $t2, 13340($t0)
        sw $t2, 13344($t0)
        sw $t2, 13348($t0)
        sw $t2, 13352($t0)
        sw $t2, 13356($t0)
        sw $t2, 13360($t0)
        sw $t2, 13364($t0)
        sw $t2, 13368($t0)
        sw $t2, 13372($t0)
        sw $t2, 13376($t0)
        sw $t2, 13380($t0)
        sw $t2, 13384($t0)
        sw $t2, 13388($t0)
        sw $t2, 13392($t0)
        sw $t2, 13396($t0)
        sw $t2, 13400($t0)
        sw $t2, 13404($t0)
        sw $t2, 13408($t0)
        sw $t2, 13412($t0)
        sw $t2, 13416($t0)
        sw $t2, 13420($t0)
        sw $t2, 13424($t0)
        sw $t2, 13428($t0)
        sw $t2, 13432($t0)
        sw $t2, 13436($t0)
        sw $t2, 13440($t0)
        sw $t2, 13444($t0)
        sw $t2, 13448($t0)
        sw $t2, 13452($t0)
        sw $t2, 13456($t0)
        sw $t2, 13460($t0)
        sw $t2, 13464($t0)
        sw $t2, 13468($t0)
        sw $t2, 13472($t0)
        sw $t2, 13476($t0)
        sw $t2, 13480($t0)
        sw $t2, 13484($t0)
        sw $t2, 13488($t0)
        sw $t2, 13492($t0)
        sw $t2, 13496($t0)
        sw $t2, 13500($t0)
        sw $t2, 13504($t0)
        sw $t2, 13508($t0)
        sw $t2, 13512($t0)
        sw $t2, 13516($t0)
        sw $t2, 13520($t0)
        sw $t2, 13524($t0)
        sw $t2, 13528($t0)
        sw $t2, 13532($t0)
        sw $t2, 13536($t0)
        sw $t2, 13540($t0)
        sw $t2, 13544($t0)
        sw $t2, 13548($t0)
        sw $t2, 13552($t0)
        sw $t2, 13556($t0)
        sw $t2, 13560($t0)
        sw $t2, 13564($t0)
        sw $t2, 13568($t0)
        sw $t2, 13572($t0)
        sw $t2, 13576($t0)
        sw $t2, 13580($t0)
        sw $t2, 13584($t0)
        sw $t2, 13588($t0)
        sw $t2, 13592($t0)
        sw $t2, 13596($t0)
        sw $t2, 13600($t0)
        sw $t2, 13604($t0)
        sw $t2, 13608($t0)
        sw $t2, 13612($t0)
        sw $t2, 13616($t0)
        sw $t2, 13620($t0)
        sw $t2, 13624($t0)
        sw $t2, 13628($t0)
        sw $t2, 13632($t0)
        sw $t2, 13636($t0)
        sw $t2, 13640($t0)
        sw $t2, 13644($t0)
        sw $t2, 13648($t0)
        sw $t2, 13652($t0)
        sw $t2, 13656($t0)
        sw $t2, 13660($t0)
        sw $t2, 13664($t0)
        sw $t2, 13668($t0)
        sw $t2, 13672($t0)
        sw $t2, 13676($t0)
        sw $t2, 13680($t0)
        sw $t2, 13684($t0)
        sw $t2, 13688($t0)
        sw $t2, 13692($t0)
        sw $t2, 13696($t0)
        sw $t2, 13700($t0)
        sw $t2, 13704($t0)
        sw $t2, 13708($t0)
        sw $t2, 13712($t0)
        sw $t2, 13716($t0)
        sw $t2, 13720($t0)
        sw $t2, 13724($t0)
        sw $t2, 13728($t0)
        sw $t2, 13732($t0)
        sw $t2, 13736($t0)
        sw $t2, 13740($t0)
        sw $t2, 13744($t0)
        sw $t2, 13748($t0)
        sw $t2, 13752($t0)
        sw $t2, 13756($t0)
        sw $t2, 13760($t0)
        sw $t2, 13764($t0)
        sw $t2, 13768($t0)
        sw $t2, 13772($t0)
        sw $t2, 13776($t0)
        sw $t2, 13780($t0)
        sw $t2, 13784($t0)
        sw $t2, 13788($t0)
        sw $t2, 13792($t0)
        sw $t2, 13796($t0)
        sw $t2, 13800($t0)
        sw $t2, 13804($t0)
        sw $t2, 13808($t0)
        sw $t2, 13812($t0)
        sw $t2, 13816($t0)
        sw $t2, 13820($t0)
        sw $t2, 13824($t0)
        sw $t2, 13828($t0)
        sw $t2, 13832($t0)
        sw $t2, 13836($t0)
        sw $t2, 13840($t0)
        sw $t2, 13844($t0)
        sw $t2, 13848($t0)
        sw $t2, 13852($t0)
        sw $t2, 13856($t0)
        sw $t2, 13860($t0)
        sw $t2, 13864($t0)
        sw $t2, 13868($t0)
        sw $t2, 13872($t0)
        sw $t2, 13876($t0)
        sw $t2, 13880($t0)
        sw $t2, 13884($t0)
        sw $t2, 13888($t0)
        sw $t2, 13892($t0)
        sw $t2, 13896($t0)
        sw $t2, 13900($t0)
        sw $t2, 13904($t0)
        sw $t2, 13908($t0)
        sw $t2, 13912($t0)
        sw $t2, 13916($t0)
        sw $t2, 13920($t0)
        sw $t2, 13924($t0)
        sw $t2, 13928($t0)
        sw $t2, 13932($t0)
        sw $t2, 13936($t0)
        sw $t2, 13940($t0)
        sw $t2, 13944($t0)
        sw $t2, 13948($t0)
        sw $t2, 13952($t0)
        sw $t2, 13956($t0)
        sw $t2, 13960($t0)
        sw $t2, 13964($t0)
        sw $t2, 13968($t0)
        sw $t2, 13972($t0)
        sw $t2, 13976($t0)
        sw $t2, 13980($t0)
        sw $t2, 13984($t0)
        sw $t2, 13988($t0)
        sw $t2, 13992($t0)
        sw $t2, 13996($t0)
        sw $t2, 14000($t0)
        sw $t2, 14004($t0)
        sw $t2, 14008($t0)
        sw $t2, 14012($t0)
        sw $t2, 14016($t0)
        sw $t2, 14020($t0)
        sw $t2, 14024($t0)
        sw $t2, 14028($t0)
        sw $t2, 14032($t0)
        sw $t2, 14036($t0)
        sw $t2, 14040($t0)
        sw $t2, 14044($t0)
        sw $t2, 14048($t0)
        sw $t2, 14052($t0)
        sw $t2, 14056($t0)
        sw $t2, 14060($t0)
        sw $t2, 14064($t0)
        sw $t2, 14068($t0)
        sw $t2, 14072($t0)
        sw $t2, 14076($t0)
        sw $t2, 14080($t0)
        sw $t2, 14084($t0)
        sw $t2, 14088($t0)
        sw $t2, 14092($t0)
        sw $t2, 14096($t0)
        sw $t2, 14100($t0)
        sw $t2, 14104($t0)
        sw $t2, 14108($t0)
        sw $t2, 14112($t0)
        sw $t2, 14116($t0)
        sw $t2, 14120($t0)
        sw $t2, 14124($t0)
        sw $t2, 14128($t0)
        sw $t2, 14132($t0)
        sw $t2, 14136($t0)
        sw $t2, 14140($t0)
        sw $t2, 14144($t0)
        sw $t2, 14148($t0)
        sw $t2, 14152($t0)
        sw $t2, 14156($t0)
        sw $t2, 14160($t0)
        sw $t2, 14164($t0)
        sw $t2, 14168($t0)
        sw $t2, 14172($t0)
        sw $t2, 14176($t0)
        sw $t2, 14180($t0)
        sw $t2, 14184($t0)
        sw $t2, 14188($t0)
        sw $t2, 14192($t0)
        sw $t2, 14196($t0)
        sw $t2, 14200($t0)
        sw $t2, 14204($t0)
        sw $t2, 14208($t0)
        sw $t2, 14212($t0)
        sw $t2, 14216($t0)
        sw $t2, 14220($t0)
        sw $t2, 14224($t0)
        sw $t2, 14228($t0)
        sw $t2, 14232($t0)
        sw $t2, 14236($t0)
        sw $t2, 14240($t0)
        sw $t2, 14244($t0)
        sw $t2, 14248($t0)
        sw $t2, 14252($t0)
        sw $t2, 14256($t0)
        sw $t2, 14260($t0)
        sw $t2, 14264($t0)
        sw $t2, 14268($t0)
        sw $t2, 14272($t0)
        sw $t2, 14276($t0)
        sw $t2, 14280($t0)
        sw $t2, 14284($t0)
        sw $t2, 14288($t0)
        sw $t2, 14292($t0)
        sw $t2, 14296($t0)
        sw $t2, 14300($t0)
        sw $t2, 14304($t0)
        sw $t2, 14308($t0)
        sw $t2, 14312($t0)
        sw $t2, 14316($t0)
        sw $t2, 14320($t0)
        sw $t2, 14324($t0)
        sw $t2, 14328($t0)
        sw $t2, 14332($t0)
        sw $t2, 14336($t0)
        sw $t2, 14340($t0)
        sw $t2, 14344($t0)
        sw $t2, 14348($t0)
        sw $t2, 14352($t0)
        sw $t2, 14356($t0)
        sw $t2, 14360($t0)
        sw $t2, 14364($t0)
        sw $t2, 14368($t0)
        sw $t2, 14372($t0)
        sw $t2, 14376($t0)
        sw $t2, 14380($t0)
        sw $t2, 14384($t0)
        sw $t2, 14388($t0)
        sw $t2, 14392($t0)
        sw $t2, 14396($t0)
        sw $t2, 14400($t0)
        sw $t2, 14404($t0)
        sw $t2, 14408($t0)
        sw $t2, 14412($t0)
        sw $t2, 14416($t0)
        sw $t2, 14420($t0)
        sw $t2, 14424($t0)
        sw $t2, 14428($t0)
        sw $t2, 14432($t0)
        sw $t2, 14436($t0)
        sw $t2, 14440($t0)
        sw $t2, 14444($t0)
        sw $t2, 14448($t0)
        sw $t2, 14452($t0)
        sw $t2, 14456($t0)
        sw $t2, 14460($t0)
        sw $t2, 14464($t0)
        sw $t2, 14468($t0)
        sw $t2, 14472($t0)
        sw $t2, 14476($t0)
        sw $t2, 14480($t0)
        sw $t2, 14484($t0)
        sw $t2, 14488($t0)
        sw $t2, 14492($t0)
        sw $t2, 14496($t0)
        sw $t2, 14500($t0)
        sw $t2, 14504($t0)
        sw $t2, 14508($t0)
        sw $t2, 14512($t0)
        sw $t2, 14516($t0)
        sw $t2, 14520($t0)
        sw $t2, 14524($t0)
        sw $t2, 14528($t0)
        sw $t2, 14532($t0)
        sw $t2, 14536($t0)
        sw $t2, 14540($t0)
        sw $t2, 14544($t0)
        sw $t2, 14548($t0)
        sw $t2, 14552($t0)
        sw $t2, 14556($t0)
        sw $t2, 14560($t0)
        sw $t2, 14564($t0)
        sw $t2, 14568($t0)
        sw $t2, 14572($t0)
        sw $t2, 14576($t0)
        sw $t2, 14580($t0)
        sw $t2, 14584($t0)
        sw $t2, 14588($t0)
        sw $t2, 14592($t0)
        sw $t2, 14596($t0)
        sw $t2, 14600($t0)
        sw $t2, 14604($t0)
        sw $t2, 14608($t0)
        sw $t2, 14612($t0)
        sw $t2, 14616($t0)
        sw $t2, 14620($t0)
        sw $t2, 14624($t0)
        sw $t2, 14628($t0)
        sw $t2, 14632($t0)
        sw $t2, 14636($t0)
        sw $t2, 14640($t0)
        sw $t2, 14644($t0)
        sw $t2, 14648($t0)
        sw $t2, 14652($t0)
        sw $t2, 14656($t0)
        sw $t2, 14660($t0)
        sw $t2, 14664($t0)
        sw $t2, 14668($t0)
        sw $t2, 14672($t0)
        sw $t2, 14676($t0)
        sw $t2, 14680($t0)
        sw $t2, 14684($t0)
        sw $t2, 14688($t0)
        sw $t2, 14692($t0)
        sw $t2, 14696($t0)
        sw $t2, 14700($t0)
        sw $t2, 14704($t0)
        sw $t2, 14708($t0)
        sw $t2, 14712($t0)
        sw $t2, 14716($t0)
        sw $t2, 14720($t0)
        sw $t2, 14724($t0)
        sw $t2, 14728($t0)
        sw $t2, 14732($t0)
        sw $t2, 14736($t0)
        sw $t2, 14740($t0)
        sw $t2, 14744($t0)
        sw $t2, 14748($t0)
        sw $t2, 14752($t0)
        sw $t2, 14756($t0)
        sw $t2, 14760($t0)
        sw $t2, 14764($t0)
        sw $t2, 14768($t0)
        sw $t2, 14772($t0)
        sw $t2, 14776($t0)
        sw $t2, 14780($t0)
        sw $t2, 14784($t0)
        sw $t2, 14788($t0)
        sw $t2, 14792($t0)
        sw $t2, 14796($t0)
        sw $t2, 14800($t0)
        sw $t2, 14804($t0)
        sw $t2, 14808($t0)
        sw $t2, 14812($t0)
        sw $t2, 14816($t0)
        sw $t2, 14820($t0)
        sw $t2, 14824($t0)
        sw $t2, 14828($t0)
        sw $t2, 14832($t0)
        sw $t2, 14836($t0)
        sw $t2, 14840($t0)
        sw $t2, 14844($t0)
        sw $t2, 14848($t0)
        sw $t2, 14852($t0)
        sw $t2, 14856($t0)
        sw $t2, 14860($t0)
        sw $t2, 14864($t0)
        sw $t2, 14868($t0)
        sw $t2, 14872($t0)
        sw $t2, 14876($t0)
        sw $t2, 14880($t0)
        sw $t2, 14884($t0)
        sw $t2, 14888($t0)
        sw $t2, 14892($t0)
        sw $t2, 14896($t0)
        sw $t2, 14900($t0)
        sw $t2, 14904($t0)
        sw $t2, 14908($t0)
        sw $t2, 14912($t0)
        sw $t2, 14916($t0)
        sw $t2, 14920($t0)
        sw $t2, 14924($t0)
        sw $t2, 14928($t0)
        sw $t2, 14932($t0)
        sw $t2, 14936($t0)
        sw $t2, 14940($t0)
        sw $t2, 14944($t0)
        sw $t2, 14948($t0)
        sw $t2, 14952($t0)
        sw $t2, 14956($t0)
        sw $t2, 14960($t0)
        sw $t2, 14964($t0)
        sw $t2, 14968($t0)
        sw $t2, 14972($t0)
        sw $t2, 14976($t0)
        sw $t2, 14980($t0)
        sw $t2, 14984($t0)
        sw $t2, 14988($t0)
        sw $t2, 14992($t0)
        sw $t2, 14996($t0)
        sw $t2, 15000($t0)
        sw $t2, 15004($t0)
        sw $t2, 15008($t0)
        sw $t2, 15012($t0)
        sw $t2, 15016($t0)
        sw $t2, 15020($t0)
        sw $t2, 15024($t0)
        sw $t2, 15028($t0)
        sw $t2, 15032($t0)
        sw $t2, 15036($t0)
        sw $t2, 15040($t0)
        sw $t2, 15044($t0)
        sw $t2, 15048($t0)
        sw $t2, 15052($t0)
        sw $t2, 15056($t0)
        sw $t2, 15060($t0)
        sw $t2, 15064($t0)
        sw $t2, 15068($t0)
        sw $t2, 15072($t0)
        sw $t2, 15076($t0)
        sw $t2, 15080($t0)
        sw $t2, 15084($t0)
        sw $t2, 15088($t0)
        sw $t2, 15092($t0)
        sw $t2, 15096($t0)
        sw $t2, 15100($t0)
        sw $t2, 15104($t0)
        sw $t2, 15108($t0)
        sw $t2, 15112($t0)
        sw $t2, 15116($t0)
        sw $t2, 15120($t0)
        sw $t2, 15124($t0)
        sw $t2, 15128($t0)
        sw $t2, 15132($t0)
        sw $t2, 15136($t0)
        sw $t2, 15140($t0)
        sw $t2, 15144($t0)
        sw $t2, 15148($t0)
        sw $t2, 15152($t0)
        sw $t2, 15156($t0)
        sw $t2, 15160($t0)
        sw $t2, 15164($t0)
        sw $t2, 15168($t0)
        sw $t2, 15172($t0)
        sw $t2, 15176($t0)
        sw $t2, 15180($t0)
        sw $t2, 15184($t0)
        sw $t2, 15188($t0)
        sw $t2, 15192($t0)
        sw $t2, 15196($t0)
        sw $t2, 15200($t0)
        sw $t2, 15204($t0)
        sw $t2, 15208($t0)
        sw $t2, 15212($t0)
        sw $t2, 15216($t0)
        sw $t2, 15220($t0)
        sw $t2, 15224($t0)
        sw $t2, 15228($t0)
        sw $t2, 15232($t0)
        sw $t2, 15236($t0)
        sw $t2, 15240($t0)
        sw $t2, 15244($t0)
        sw $t2, 15248($t0)
        sw $t2, 15252($t0)
        sw $t2, 15256($t0)
        sw $t2, 15260($t0)
        sw $t2, 15264($t0)
        sw $t2, 15268($t0)
        sw $t2, 15272($t0)
        sw $t2, 15276($t0)
        sw $t2, 15280($t0)
        sw $t2, 15284($t0)
        sw $t2, 15288($t0)
        sw $t2, 15292($t0)
        sw $t2, 15296($t0)
        sw $t2, 15300($t0)
        sw $t2, 15304($t0)
        sw $t2, 15308($t0)
        sw $t2, 15312($t0)
        sw $t2, 15316($t0)
        sw $t2, 15320($t0)
        sw $t2, 15324($t0)
        sw $t2, 15328($t0)
        sw $t2, 15332($t0)
        sw $t2, 15336($t0)
        sw $t2, 15340($t0)
        sw $t2, 15344($t0)
        sw $t2, 15348($t0)
        sw $t2, 15352($t0)
        sw $t2, 15356($t0)
        sw $t2, 15360($t0)
        sw $t2, 15364($t0)
        sw $t2, 15368($t0)
        sw $t2, 15372($t0)
        sw $t2, 15376($t0)
        sw $t2, 15380($t0)
        sw $t2, 15384($t0)
        sw $t2, 15388($t0)
        sw $t2, 15392($t0)
        sw $t2, 15396($t0)
        sw $t2, 15400($t0)
        sw $t2, 15404($t0)
        sw $t2, 15408($t0)
        sw $t2, 15412($t0)
        sw $t2, 15416($t0)
        sw $t2, 15420($t0)
        sw $t2, 15424($t0)
        sw $t2, 15428($t0)
        sw $t2, 15432($t0)
        sw $t2, 15436($t0)
        sw $t2, 15440($t0)
        sw $t2, 15444($t0)
        sw $t2, 15448($t0)
        sw $t2, 15452($t0)
        sw $t2, 15456($t0)
        sw $t2, 15460($t0)
        sw $t2, 15464($t0)
        sw $t2, 15468($t0)
        sw $t2, 15472($t0)
        sw $t2, 15476($t0)
        sw $t2, 15480($t0)
        sw $t2, 15484($t0)
        sw $t2, 15488($t0)
        sw $t2, 15492($t0)
        sw $t2, 15496($t0)
        sw $t2, 15500($t0)
        sw $t2, 15504($t0)
        sw $t2, 15508($t0)
        sw $t2, 15512($t0)
        sw $t2, 15516($t0)
        sw $t2, 15520($t0)
        sw $t2, 15524($t0)
        sw $t2, 15528($t0)
        sw $t2, 15532($t0)
        sw $t2, 15536($t0)
        sw $t2, 15540($t0)
        sw $t2, 15544($t0)
        sw $t2, 15548($t0)
        sw $t2, 15552($t0)
        sw $t2, 15556($t0)
        sw $t2, 15560($t0)
        sw $t2, 15564($t0)
        sw $t2, 15568($t0)
        sw $t2, 15572($t0)
        sw $t2, 15576($t0)
        sw $t2, 15580($t0)
        sw $t2, 15584($t0)
        sw $t2, 15588($t0)
        sw $t2, 15592($t0)
        sw $t2, 15596($t0)
        sw $t2, 15600($t0)
        sw $t2, 15604($t0)
        sw $t2, 15608($t0)
        sw $t2, 15612($t0)
        sw $t2, 15616($t0)
        sw $t2, 15620($t0)
        sw $t2, 15624($t0)
        sw $t2, 15628($t0)
        sw $t2, 15632($t0)
        sw $t2, 15636($t0)
        sw $t2, 15640($t0)
        sw $t2, 15644($t0)
        sw $t2, 15648($t0)
        sw $t2, 15652($t0)
        sw $t2, 15656($t0)
        sw $t2, 15660($t0)
        sw $t2, 15664($t0)
        sw $t2, 15668($t0)
        sw $t2, 15672($t0)
        sw $t2, 15676($t0)
        sw $t2, 15680($t0)
        sw $t2, 15684($t0)
        sw $t2, 15688($t0)
        sw $t2, 15692($t0)
        sw $t2, 15696($t0)
        sw $t2, 15700($t0)
        sw $t2, 15704($t0)
        sw $t2, 15708($t0)
        sw $t2, 15712($t0)
        sw $t2, 15716($t0)
        sw $t2, 15720($t0)
        sw $t2, 15724($t0)
        sw $t2, 15728($t0)
        sw $t2, 15732($t0)
        sw $t2, 15736($t0)
        sw $t2, 15740($t0)
        sw $t2, 15744($t0)
        sw $t2, 15748($t0)
        sw $t2, 15752($t0)
        sw $t2, 15756($t0)
        sw $t2, 15760($t0)
        sw $t2, 15764($t0)
        sw $t2, 15768($t0)
        sw $t2, 15772($t0)
        sw $t2, 15776($t0)
        sw $t2, 15780($t0)
        sw $t2, 15784($t0)
        sw $t2, 15788($t0)
        sw $t2, 15792($t0)
        sw $t2, 15796($t0)
        sw $t2, 15800($t0)
        sw $t2, 15804($t0)
        sw $t2, 15808($t0)
        sw $t2, 15812($t0)
        sw $t2, 15816($t0)
        sw $t2, 15820($t0)
        sw $t2, 15824($t0)
        sw $t2, 15828($t0)
        sw $t2, 15832($t0)
        sw $t2, 15836($t0)
        sw $t2, 15840($t0)
        sw $t2, 15844($t0)
        sw $t2, 15848($t0)
        sw $t2, 15852($t0)
        sw $t2, 15856($t0)
        sw $t2, 15860($t0)
        sw $t2, 15864($t0)
        sw $t2, 15868($t0)
        sw $t2, 15872($t0)
        sw $t2, 15876($t0)
        sw $t2, 15880($t0)
        sw $t2, 15884($t0)
        sw $t2, 15888($t0)
        sw $t2, 15892($t0)
        sw $t2, 15896($t0)
        sw $t2, 15900($t0)
        sw $t2, 15904($t0)
        sw $t2, 15908($t0)
        sw $t2, 15912($t0)
        sw $t2, 15916($t0)
        sw $t2, 15920($t0)
        sw $t2, 15924($t0)
        sw $t2, 15928($t0)
        sw $t2, 15932($t0)
        sw $t2, 15936($t0)
        sw $t2, 15940($t0)
        sw $t2, 15944($t0)
        sw $t2, 15948($t0)
        sw $t2, 15952($t0)
        sw $t2, 15956($t0)
        sw $t2, 15960($t0)
        sw $t2, 15964($t0)
        sw $t2, 15968($t0)
        sw $t2, 15972($t0)
        sw $t2, 15976($t0)
        sw $t2, 15980($t0)
        sw $t2, 15984($t0)
        sw $t2, 15988($t0)
        sw $t2, 15992($t0)
        sw $t2, 15996($t0)
        sw $t2, 16000($t0)
        sw $t2, 16004($t0)
        sw $t2, 16008($t0)
        sw $t2, 16012($t0)
        sw $t2, 16016($t0)
        sw $t2, 16020($t0)
        sw $t2, 16024($t0)
        sw $t2, 16028($t0)
        sw $t2, 16032($t0)
        sw $t2, 16036($t0)
        sw $t2, 16040($t0)
        sw $t2, 16044($t0)
        sw $t2, 16048($t0)
        sw $t2, 16052($t0)
        sw $t2, 16056($t0)
        sw $t2, 16060($t0)
        sw $t2, 16064($t0)
        sw $t2, 16068($t0)
        sw $t2, 16072($t0)
        sw $t2, 16076($t0)
        sw $t2, 16080($t0)
        sw $t2, 16084($t0)
        sw $t2, 16088($t0)
        sw $t2, 16092($t0)
        sw $t2, 16096($t0)
        sw $t2, 16100($t0)
        sw $t2, 16104($t0)
        sw $t2, 16108($t0)
        sw $t2, 16112($t0)
        sw $t2, 16116($t0)
        sw $t2, 16120($t0)
        sw $t2, 16124($t0)
        sw $t2, 16128($t0)
        sw $t2, 16132($t0)
        sw $t2, 16136($t0)
        sw $t2, 16140($t0)
        sw $t2, 16144($t0)
        sw $t2, 16148($t0)
        sw $t2, 16152($t0)
        sw $t2, 16156($t0)
        sw $t2, 16160($t0)
        sw $t2, 16164($t0)
        sw $t2, 16168($t0)
        sw $t2, 16172($t0)
        sw $t2, 16176($t0)
        sw $t2, 16180($t0)
        sw $t2, 16184($t0)
        sw $t2, 16188($t0)
        sw $t2, 16192($t0)
        sw $t2, 16196($t0)
        sw $t2, 16200($t0)
        sw $t2, 16204($t0)
        sw $t2, 16208($t0)
        sw $t2, 16212($t0)
        sw $t2, 16216($t0)
        sw $t2, 16220($t0)
        sw $t2, 16224($t0)
        sw $t2, 16228($t0)
        sw $t2, 16232($t0)
        sw $t2, 16236($t0)
        sw $t2, 16240($t0)
        sw $t2, 16244($t0)
        sw $t2, 16248($t0)
        sw $t2, 16252($t0)
        sw $t2, 16256($t0)
        sw $t2, 16260($t0)
        sw $t2, 16264($t0)
        sw $t2, 16268($t0)
        sw $t2, 16272($t0)
        sw $t2, 16276($t0)
        sw $t2, 16280($t0)
        sw $t2, 16284($t0)
        sw $t2, 16288($t0)
        sw $t2, 16292($t0)
        sw $t2, 16296($t0)
        sw $t2, 16300($t0)
        sw $t2, 16304($t0)
        sw $t2, 16308($t0)
        sw $t2, 16312($t0)
        sw $t2, 16316($t0)
        sw $t2, 16320($t0)
        sw $t2, 16324($t0)
        sw $t2, 16328($t0)
        sw $t2, 16332($t0)
        sw $t2, 16336($t0)
        sw $t2, 16340($t0)
        sw $t2, 16344($t0)
        sw $t2, 16348($t0)
        sw $t2, 16352($t0)
        sw $t2, 16356($t0)
        sw $t2, 16360($t0)
        sw $t2, 16364($t0)
        sw $t2, 16368($t0)
        sw $t2, 16372($t0)
        sw $t2, 16376($t0)
        sw $t2, 16380($t0)
        
        li $a0, 0x00ffffff
        li $a1, DISPLAY_ADDR
        addi $a1, $a1, 108
        addi $a1, $a1, 9472
        move $a2, $t2
        
        jal draw_coin_counter

	jr $ra
	
	
	
	


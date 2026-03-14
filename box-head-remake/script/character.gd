extends CharacterBody2D

var angle=0  #角度
var currAni=""
var isDead=false
var invincible=false
var state   #状态

@export var hp:int=10 #血量
@export var speed=120 #移动速度

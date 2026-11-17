import { ApiProperty } from '@nestjs/swagger';
import { Equals, IsBoolean, IsString } from 'class-validator';
export class ConsentDto {
  @ApiProperty({ example: true }) @IsBoolean() @Equals(true) consent!: boolean;
  @ApiProperty({ example: '2' }) @IsString() @Equals('2') version!: string;
}

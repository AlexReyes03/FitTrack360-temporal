import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { HealthResponseDto } from './dto/health-response.dto';
import { HealthService } from './health.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @ApiOkResponse({
    type: HealthResponseDto,
    description: 'El proceso responde; db indica si Postgres está disponible.',
  })
  check(): Promise<HealthResponseDto> {
    return this.healthService.check();
  }
}
